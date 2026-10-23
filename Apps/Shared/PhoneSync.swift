import Foundation
import WatchConnectivity
import BatwalkCore

/// Best-effort Watch ↔ iPhone sync (PRD §4.1).
///
/// - Watch → iPhone: a redacted collection mirror goes into the Watch's application context
///   (only the latest matters to a mirror; a large history uses a file transfer).
/// - iPhone → Watch: companion-change requests (`transferUserInfo`, queued), and
///   the phone's latest *collection backup* in the phone's application context,
///   so a replaced or re-paired Watch can restore the collection without iCloud
///   (2026-10-10 review, finding 2). Health-derived data never travels this way.
///
/// CloudKit backs up collection metadata only; complete saves never enter CloudKit.
final class PhoneSync: NSObject, WCSessionDelegate {
    static let shared = PhoneSync()

    /// Called on the main actor with the Watch's encoded `GameState`.
    var onReceiveSave: (@MainActor (Data, Date?) -> Void)?
    var onReceiveRequest: (@MainActor (CompanionChangeRequest) -> Void)?
    var onReceiveReceipt: (@MainActor (CompanionChangeReceipt) -> Void)?
    /// Watch only: the collection backup the paired iPhone last published.
    var onReceivePhoneBackup: (@MainActor (CollectionBackup) -> Void)?
    /// Called once the session is active (the phone publishes its backup here).
    var onActivated: (@MainActor () -> Void)?

    /// Watch-only resolver; replies are read-only and never queued or saved.
    var certificateMetrics: (@MainActor (CertificateMetricsRequest) -> CertificateMetrics?)?
    private static let certificateKey = "certificateMetrics"

    enum CertificateError: Error { case unavailable, missingReceipt }

    @MainActor
    func requestCertificateMetrics(_ request: CertificateMetricsRequest,
                                   completion: @escaping @MainActor (Result<CertificateMetrics, CertificateError>) -> Void) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isReachable,
              let data = try? JSONEncoder().encode(request) else {
            completion(.failure(.unavailable)); return
        }
        WCSession.default.sendMessage([Self.certificateKey: data], replyHandler: { reply in
            let result: Result<CertificateMetrics, CertificateError>
            if let data = reply[Self.certificateKey] as? Data,
               let metrics = try? JSONDecoder().decode(CertificateMetrics.self, from: data) {
                result = .success(metrics)
            } else { result = .failure(.missingReceipt) }
            Task { @MainActor in completion(result) }
        }, errorHandler: { _ in
            Task { @MainActor in completion(.failure(.unavailable)) }
        })
    }

    private static let saveKey = "save"
    private static let updatedKey = "updatedAt"
    private static let requestKey = "companionRequest"
    private static let receiptKey = "companionReceipt"
    private static let phoneBackupKey = "collectionBackup"
    static let fileSaveKey = "batwalk-save"
    static func usesFileTransfer(forByteCount count: Int) -> Bool { count > 50_000 }
    /// The application context is small; the phone's backup must fit under this.
    static let maxPhoneBackupBytes = 60_000
    private let pendingLock = NSLock()
    private let flushLock = NSLock()
    private var pendingSave: Data?
    private var cancelledLegacyFiles: Set<URL> = []

    enum SendResult { case sent, noWatchApp, unavailable }

    func send(request: CompanionChangeRequest) -> SendResult {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              let data = try? JSONEncoder().encode(request) else { return .unavailable }
        #if os(iOS)
        guard WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return .noWatchApp }
        #endif
        WCSession.default.transferUserInfo([Self.requestKey: data])
        return .sent
    }

    func reply(_ receipt: CompanionChangeReceipt, save: Data?) {
        guard WCSession.isSupported(), let data = try? JSONEncoder().encode(receipt) else { return }
        WCSession.default.transferUserInfo([Self.receiptKey: data])
        if let save { push(save: save) }
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: Watch → iPhone save

    func push(save data: Data) {
        // Never trust callers to remember the privacy boundary.
        guard let data = Self.sanitizedMirrorData(data) else { return }
        pendingLock.lock(); pendingSave = data; pendingLock.unlock()
        flushPendingSave()
    }

    static func sanitizedMirrorData(_ data: Data) -> Data? {
        guard let state = try? JSONDecoder().decode(GameState.self, from: data) else { return nil }
        return try? JSONEncoder().encode(state.collectionMirror())
    }

    static func mirrorTransferNeedsRedaction(_ data: Data?) -> Bool {
        guard let data, let state = try? JSONDecoder().decode(GameState.self, from: data) else { return true }
        return state != state.collectionMirror()
    }

    private func isCancelledLegacyFile(_ url: URL) -> Bool {
        pendingLock.lock(); defer { pendingLock.unlock() }
        return cancelledLegacyFiles.contains(url)
    }

    /// An app update can inherit transfers queued by its previous version.
    /// Cancel what the app can still control; activation then publishes the
    /// current local save through the redacted push boundary. Already delivered
    /// data cannot be recalled from the connectivity system.
    private func cancelLegacyMirrorTransfers() {
        for transfer in WCSession.default.outstandingFileTransfers {
            guard transfer.file.metadata?[Self.fileSaveKey] as? Bool == true,
                  !isCancelledLegacyFile(transfer.file.fileURL),
                  Self.mirrorTransferNeedsRedaction(try? Data(contentsOf: transfer.file.fileURL)) else { continue }
            pendingLock.lock(); cancelledLegacyFiles.insert(transfer.file.fileURL); pendingLock.unlock()
            transfer.cancel()
        }
    }

    private func flushPendingSave() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        // One flush at a time: the delegate queue and the main thread can both get
        // here, and an older snapshot must never overwrite a newer context.
        flushLock.lock(); defer { flushLock.unlock() }
        cancelLegacyMirrorTransfers()
        pendingLock.lock(); let data = pendingSave; pendingLock.unlock()
        guard let data else { return }
        do {
            if Self.usesFileTransfer(forByteCount: data.count) {
                // Long hatch histories must not exceed application-context limits.
                // One transfer in flight at a time; the newest save goes out when it
                // finishes, so a busy Watch never builds a backlog of stale files.
                let inFlight = WCSession.default.outstandingFileTransfers.contains {
                    $0.file.metadata?[Self.fileSaveKey] as? Bool == true && !isCancelledLegacyFile($0.file.fileURL)
                }
                guard !inFlight else { return } // pendingSave stays set
                let file = FileManager.default.temporaryDirectory.appendingPathComponent("batwalk-mirror-\(UUID().uuidString).json")
                try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                WCSession.default.transferFile(file, metadata: [Self.fileSaveKey: true, Self.updatedKey: Date().timeIntervalSince1970])
            } else {
                try WCSession.default.updateApplicationContext([Self.saveKey: data, Self.updatedKey: Date().timeIntervalSince1970])
            }
            pendingLock.lock()
            if pendingSave == data { pendingSave = nil }
            pendingLock.unlock()
        } catch { /* retry the latest snapshot on activation / next foreground push */ }
    }

    // MARK: iPhone → Watch collection backup

    /// The phone keeps its newest collection backup in its outgoing application
    /// context (delivered even while the Watch app is closed, kept across launches).
    /// Trimmed to the newest 100 hatches when the full history would not fit.
    func publish(phoneBackup: CollectionBackup) {
        #if os(iOS)
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        var backup = phoneBackup
        var data = try? JSONEncoder().encode(backup)
        if let bytes = data, bytes.count > Self.maxPhoneBackupBytes {
            backup = backup.trimmingHistory(to: 100)
            data = try? JSONEncoder().encode(backup)
        }
        guard let data, data.count <= Self.maxPhoneBackupBytes else { return }
        if let current = WCSession.default.applicationContext[Self.phoneBackupKey] as? Data,
           let previous = try? JSONDecoder().decode(CollectionBackup.self, from: current),
           previous.hasSameContent(as: backup) { return }
        try? WCSession.default.updateApplicationContext([Self.phoneBackupKey: data])
        #endif
    }

    /// Watch only: whatever backup the phone last published, if the session has one.
    func receivedPhoneBackup() -> CollectionBackup? {
        #if os(watchOS)
        guard WCSession.isSupported(),
              let data = WCSession.default.receivedApplicationContext[Self.phoneBackupKey] as? Data else { return nil }
        return try? JSONDecoder().decode(CollectionBackup.self, from: data)
        #else
        return nil
        #endif
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if state == .activated {
            flushPendingSave()
            Task { @MainActor in self.onActivated?() }
        }
        // Pick up whatever the other device sent while we were not running.
        if let data = session.receivedApplicationContext[Self.saveKey] as? Data {
            deliver(data, timestamp: session.receivedApplicationContext[Self.updatedKey] as? Double)
        }
        deliverPhoneBackup(from: session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext[Self.saveKey] as? Data {
            deliver(data, timestamp: applicationContext[Self.updatedKey] as? Double)
        }
        deliverPhoneBackup(from: applicationContext)
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // The system removes this URL after the delegate returns; copy its bytes now.
        guard file.metadata?[Self.fileSaveKey] as? Bool == true,
              let data = try? Data(contentsOf: file.fileURL) else { return }
        deliver(data, timestamp: file.metadata?[Self.updatedKey] as? Double)
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        let file = fileTransfer.file.fileURL
        guard fileTransfer.file.metadata?[Self.fileSaveKey] as? Bool == true,
              file.lastPathComponent.hasPrefix("batwalk-mirror-") else { return }
        pendingLock.lock()
        let wasCancelledForPrivacy = cancelledLegacyFiles.remove(file) != nil
        pendingLock.unlock()
        // A failed transfer can belong to a version installed before mirror
        // redaction. Never put those original bytes back into the send queue.
        if !wasCancelledForPrivacy, error != nil, let original = try? Data(contentsOf: file),
           let data = Self.sanitizedMirrorData(original) {
            pendingLock.lock()
            if pendingSave == nil { pendingSave = data }
            pendingLock.unlock()
        }
        try? FileManager.default.removeItem(at: file)
        flushPendingSave() // send the newest save that queued up while this one was in flight
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        guard let data = message[Self.certificateKey] as? Data,
              let request = try? JSONDecoder().decode(CertificateMetricsRequest.self, from: data) else {
            replyHandler([:]); return
        }
        Task { @MainActor in
            guard let metrics = self.certificateMetrics?(request),
                  let encoded = try? JSONEncoder().encode(metrics) else { replyHandler([:]); return }
            replyHandler([Self.certificateKey: encoded])
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let data = userInfo[Self.requestKey] as? Data,
           let request = try? JSONDecoder().decode(CompanionChangeRequest.self, from: data) {
            Task { @MainActor in self.onReceiveRequest?(request) }
            return
        }
        if let data = userInfo[Self.receiptKey] as? Data,
           let receipt = try? JSONDecoder().decode(CompanionChangeReceipt.self, from: data) {
            Task { @MainActor in self.onReceiveReceipt?(receipt) }
        }
        // Anything else is ignored: every Watch-side change goes through a signed,
        // expiring request with a saveID (no legacy free-form commands).
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif

    private func deliver(_ data: Data, timestamp: Double?) {
        Task { @MainActor in
            self.onReceiveSave?(data, timestamp.map { Date(timeIntervalSince1970: $0) })
        }
    }

    private func deliverPhoneBackup(from context: [String: Any]) {
        guard let data = context[Self.phoneBackupKey] as? Data,
              let backup = try? JSONDecoder().decode(CollectionBackup.self, from: data) else { return }
        Task { @MainActor in self.onReceivePhoneBackup?(backup) }
    }
}
