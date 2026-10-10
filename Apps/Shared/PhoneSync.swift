import Foundation
import WatchConnectivity

/// Best-effort Watch → iPhone sync (PRD §4.1). The Watch pushes its whole save
/// as the WatchConnectivity application context; only the latest one is kept,
/// which is exactly the semantics a mirror needs. CloudKit backs up collection
/// metadata only; complete Health-derived saves never enter CloudKit.
final class PhoneSync: NSObject, WCSessionDelegate {
    static let shared = PhoneSync()

    /// Called on the main actor with the Watch's encoded `GameState`.
    var onReceiveSave: (@MainActor (Data) -> Void)?
    /// Watch only: requests from the iPhone, applied by the Watch (the only writer).
    var onReceiveCommand: (@MainActor ([String: String]) -> Void)?

    static let setCompanionKey = "setCompanion"
    private static let saveKey = "save"
    private let pendingLock = NSLock()
    private var pendingSave: Data?

    enum SendResult { case sent, noWatchApp, unavailable }

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
            try WCSession.default.updateApplicationContext([Self.saveKey: data])
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
            deliver(data)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext[Self.saveKey] as? Data {
            deliver(data)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let command = userInfo.compactMapValues { $0 as? String }
        Task { @MainActor in
            self.onReceiveCommand?(command)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif

    private func deliver(_ data: Data) {
        Task { @MainActor in
            self.onReceiveSave?(data)
        }
    }
}
