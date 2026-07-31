import SwiftUI

// MARK: - ContentView
/// Root container. Hosts Dashboard + Settings tabs and overlays the debug console.
struct ContentView: View {

    @StateObject private var socket = SocketManager()
    @AppStorage("debug_overlay_enabled") private var debugEnabled = true
    @State private var selectedTab = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    DashboardView(socket: socket)
                        .navigationBarHidden(true)
                }
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent")
                }
                .tag(0)

                NavigationStack {
                    TrackpadView(socket: socket)
                        .navigationBarHidden(true)
                }
                .tabItem {
                    Label("Trackpad", systemImage: "cursorarrow")
                }
                .tag(2)

                NavigationStack {
                    SettingsView(socket: socket)
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(1)
            }
            .tint(.white)

            // Floating debug overlay (bottom-right corner)
            if debugEnabled {
                DebugOverlayView()
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                BackgroundEngine.shared.start()
                socket.connect()
                ClipboardSync.shared.start(socketManager: socket)
                WatchSessionManager.shared.startSending()
            case .background:
                // BackgroundEngine keeps process alive — do NOT disconnect here
                DebugLogger.shared.log("📱 App moved to background — keeping socket alive.")
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onReceive(socket.$telemetry) { telemetry in
            // Update Live Activity on each new frame
            if socket.connectionState == .connected {
                LiveActivityManager.shared.updateActivity(telemetry: telemetry)
                WatchSessionManager.shared.update(telemetry: telemetry)
                if let clip = telemetry.clipboard {
                    ClipboardSync.shared.receive(text: clip)
                }
            }
        }
        .onReceive(socket.$connectionState) { state in
            switch state {
            case .connected:
                LiveActivityManager.shared.startActivity(
                    pcName: "Legion PC",
                    telemetry: socket.telemetry
                )
            case .disconnected:
                LiveActivityManager.shared.endActivity()
            case .connecting:
                break
            }
        }
    }
}
