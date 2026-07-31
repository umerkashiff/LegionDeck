import WatchConnectivity
import Foundation

// MARK: - WatchSessionManager (iOS side)
/// Sends telemetry to the Apple Watch Series 8 via WCSession.
/// Uses updateApplicationContext (no daily budget limit, always-latest semantics).
/// Sends every 5 seconds to preserve Watch battery.
@MainActor
final class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    @Published var isWatchReachable = false

    private var sendTask: Task<Void, Never>?
    private var latestTelemetry: TelemetryModel = .placeholder

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            DebugLogger.shared.log("⌚ WCSession activating…")
        } else {
            DebugLogger.shared.log("⌚ WatchConnectivity not supported on this device.")
        }
    }

    func update(telemetry: TelemetryModel) {
        latestTelemetry = telemetry
    }

    func startSending() {
        sendTask?.cancel()
        sendTask = Task { await sendLoop() }
    }

    func stopSending() {
        sendTask?.cancel()
        sendTask = nil
    }

    private func sendLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
            guard WCSession.default.activationState == .activated,
                  WCSession.default.isPaired,
                  WCSession.default.isWatchAppInstalled else { continue }
            sendContext(latestTelemetry)
        }
    }

    private func sendContext(_ t: TelemetryModel) {
        let dict: [String: Any] = [
            "cpu_usage":  t.cpuUsage,
            "gpu_usage":  t.gpuUsage,
            "ram_usage":  t.ramUsage,
            "vram_usage": t.vramUsage,
            "temp_cpu":   t.tempCpu,
            "temp_gpu":   t.tempGpu,
            "gpu_label":  t.gpuLabel ?? "N/A",
            "timestamp":  t.timestamp,
        ]
        do {
            try WCSession.default.updateApplicationContext(dict)
        } catch {
            DebugLogger.shared.log("⌚ WCSession send error: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchSessionManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                DebugLogger.shared.log("⌚ WCSession activation error: \(error.localizedDescription)")
            } else {
                DebugLogger.shared.log("⌚ WCSession activated: \(activationState.rawValue)")
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            DebugLogger.shared.log("⌚ WCSession became inactive.")
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        Task { @MainActor in
            DebugLogger.shared.log("⌚ WCSession deactivated — reactivating.")
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            DebugLogger.shared.log("⌚ Watch reachable: \(session.isReachable)")
        }
    }
}
