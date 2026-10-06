import Foundation
import WatchConnectivity

/// Best-effort Watch → iPhone sync (PRD §4.1). The Watch pushes its whole save
/// as the WatchConnectivity application context; only the latest one is kept,
/// which is exactly the semantics a mirror needs. CloudKit is the durable path.
final class PhoneSync: NSObject, WCSessionDelegate {
    static let shared = PhoneSync()

    /// Called on the main actor with the Watch's encoded `GameState`.
    var onReceiveSave: (@MainActor (Data) -> Void)?

    private static let saveKey = "save"

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func push(save data: Data) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext([Self.saveKey: data])
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
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
