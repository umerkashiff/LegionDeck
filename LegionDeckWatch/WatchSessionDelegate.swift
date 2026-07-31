import WatchConnectivity
import WidgetKit
import Foundation

// MARK: - WatchSessionDelegate (watchOS side)
/// Receives telemetry from the iOS app via WCSession.applicationContext.
/// Persists to AppGroup UserDefaults so the WidgetKit complication can read it.
class WatchSessionDelegate: NSObject, WCSessionDelegate, ObservableObject {

    static let shared = WatchSessionDelegate()

    /// AppGroup suite name — must match in both Watch app and Watch Widget Extension.
    static let appGroupID = "group.com.legiondeck.app"

    @Published var telemetry: [String: Any] = [:]

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Receive context from iPhone
    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.telemetry = applicationContext
            self.persistToAppGroup(applicationContext)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func persistToAppGroup(_ dict: [String: Any]) {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }
        defaults.set(dict["cpu_usage"]  as? Int ?? 0,    forKey: "cpu_usage")
        defaults.set(dict["gpu_usage"]  as? Int ?? 0,    forKey: "gpu_usage")
        defaults.set(dict["ram_usage"]  as? Int ?? 0,    forKey: "ram_usage")
        defaults.set(dict["vram_usage"] as? Int ?? 0,    forKey: "vram_usage")
        defaults.set(dict["temp_cpu"]   as? Int ?? 0,    forKey: "temp_cpu")
        defaults.set(dict["temp_gpu"]   as? Int ?? 0,    forKey: "temp_gpu")
        defaults.set(dict["gpu_label"]  as? String ?? "", forKey: "gpu_label")
        defaults.set(Date().timeIntervalSince1970,        forKey: "last_update")
    }
    
    // MARK: - Send Commands to iOS
    func sendCommand(_ dict: [String: Any]) {
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: { error in
                print("Failed to send command: \(error.localizedDescription)")
            })
        }
    }

    // MARK: - Required WCSession delegates
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
}
