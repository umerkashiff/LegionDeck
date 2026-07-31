import ActivityKit
import Foundation

// MARK: - LiveActivityManager
/// Manages the lifecycle of the LegionDeck Live Activity (Dynamic Island).
/// Gracefully handles unavailability (e.g., when running in LiveContainer).
@MainActor
final class LiveActivityManager {

    static let shared = LiveActivityManager()
    private var activity: Activity<LegionActivityAttributes>?

    private init() {}

    func startActivity(pcName: String, telemetry: TelemetryModel, isAuthRequested: Bool = false) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            DebugLogger.shared.log("⚠️ Live Activities not available on this device/config.")
            return
        }
        guard activity == nil else { return }
        
        let attributes = LegionActivityAttributes(pcName: pcName)
        let state = contentState(from: telemetry, isAuthRequested: isAuthRequested)

        Task {
            // 1. Clean up any lingering activities first
            for existing in Activity<LegionActivityAttributes>.activities {
                await existing.end(nil, dismissalPolicy: .immediate)
            }
            
            // 2. Create the new activity sequentially
            do {
                let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(5))
                self.activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                DebugLogger.shared.log("🏝 Live Activity started (Dynamic Island active).")
            } catch {
                DebugLogger.shared.log("❌ Live Activity start failed: \(error.localizedDescription)")
            }
        }
    }

    func updateActivity(telemetry: TelemetryModel, isAuthRequested: Bool = false) {
        guard let activity else { return }
        let state = contentState(from: telemetry, isAuthRequested: isAuthRequested)
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(5))
        Task {
            await activity.update(content)
        }
    }

    func endActivity() {
        guard let activity else { return }
        Task {
            let finalState = contentState(from: .placeholder, isAuthRequested: false)
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(60)))
            DebugLogger.shared.log("🏝 Live Activity ended.")
        }
        self.activity = nil
    }

    private func contentState(from t: TelemetryModel, isAuthRequested: Bool) -> LegionActivityAttributes.ContentState {
        return LegionActivityAttributes.ContentState(
            cpuUsage: t.cpuUsage,
            gpuUsage: t.gpuUsage,
            ramUsage: t.ramUsage,
            vramUsage: t.vramUsage,
            tempCpu: t.tempCpu,
            tempGpu: t.tempGpu,
            mediaTitle: t.mediaTitle,
            mediaArtist: t.mediaArtist,
            volume: t.volume,
            isAuthRequested: isAuthRequested
        )
    }
}
