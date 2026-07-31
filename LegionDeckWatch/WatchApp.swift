import SwiftUI

// MARK: - WatchApp
@main
struct LegionDeckWatchApp: App {
    @StateObject private var session = WatchSessionDelegate.shared

    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
                .environmentObject(session)
        }
    }
}
