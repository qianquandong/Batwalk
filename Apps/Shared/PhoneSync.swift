import Foundation
import WatchConnectivity
import BatwalkCore

/// Best-effort Watch → iPhone sync (PRD §4.1). The Watch pushes its whole save
/// as the WatchConnectivity application context; only the latest one is kept,
/// which is exactly the semantics a mirror needs. CloudKit backs up collection
/// metadata only; complete Health-derived saves never enter CloudKit.
final class PhoneSync: NSObject, WCSessionDelegate {
    static let shared = PhoneSync()

    /// Called on the main actor with the Watch's encoded `GameState`.
    var onReceiveSave: (@MainActor (Data, Date?) -> Void)?
    var onReceiveRequest: (@MainActor (CompanionChangeRequest) -> Void)?
    var onReceiveReceipt: (@MainActor (CompanionChangeReceipt) -> Void)?
    /// Watch only: requests from the iPhone, applied by the Watch (the only writer).
    var onReceiveCommand: (@MainActor ([String: String]) -> Void)?

    static let setCompanionKey = "setCompanion"
    private static let saveKey = "save"
    private static let updatedKey = "updatedAt"
    private static let requestKey = "companionRequest"
    private static let receiptKey = "companionReceipt"
    static let fileSaveKey = "batwalk-save"
    static func usesFileTransfer(forByteCount count: Int) -> Bool { count > 50_000 }
    private let pendingLock = NSLock()
    private var pendingSave: Data?

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

    /// iPhone → Watch request. `transferUserInfo` is queued and delivered even
    /// when the Watch app isn't running.
    @discardableResult
    func send(command: [String: String]) -> SendResult {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return .unavailable }
        #if os(iOS)
        guard WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return .noWatchApp }
        #endif
        WCSession.default.transferUserInfo(command)
        return .sent
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func push(save data: Data) {
        pendingLock.lock(); pendingSave = data; pendingLock.unlock()
        flushPendingSave()
    }

    private func flushPendingSave() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        pendingLock.lock(); let data = pendingSave; pendingLock.unlock()
        guard let data else { return }
        do {
            if Self.usesFileTransfer(forByteCount: data.count) {
                // Long hatch histories must not exceed application-context limits.
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

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if state == .activated { flushPendingSave() }
        // On the iPhone, pick up whatever the Watch sent while we were not running.
        if let data = session.receivedApplicationContext[Self.saveKey] as? Data {
            deliver(data, timestamp: session.receivedApplicationContext[Self.updatedKey] as? Double)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext[Self.saveKey] as? Data {
            deliver(data, timestamp: applicationContext[Self.updatedKey] as? Double)
        }
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
        if error != nil, let data = try? Data(contentsOf: file) {
            pendingLock.lock()
            if pendingSave == nil { pendingSave = data }
            pendingLock.unlock()
        }
        try? FileManager.default.removeItem(at: file)
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
            return
        }
        let command = userInfo.compactMapValues { $0 as? String }
        Task { @MainActor in
            self.onReceiveCommand?(command)
        }
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
}
