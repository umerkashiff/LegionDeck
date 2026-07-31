import AVFoundation

// MARK: - BackgroundEngine
/// Keeps the app process alive in the background using a silent audio loop.
/// This prevents iOS from suspending the WebSocket connection when the screen
/// is off or the user switches apps.
///
/// Requires Info.plist: UIBackgroundModes = [audio]
/// Works for sideloaded apps; App Store builds would be rejected for this.
@MainActor
final class BackgroundEngine {

    static let shared = BackgroundEngine()

    private var player: AVAudioPlayer?
    private var isRunning = false

    private init() {}

    func start() {
        guard !isRunning else { return }

        do {
            // Configure audio session for background playback, mixing with other audio
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)

            // Load the bundled 1-second silent MP3
            guard let url = Bundle.main.url(forResource: "silence", withExtension: "mp3") else {
                DebugLogger.shared.log("⚠️ BackgroundEngine: silence.mp3 not found in bundle.")
                return
            }

            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1   // infinite loop
            player?.volume = 0.0         // completely silent
            player?.prepareToPlay()
            player?.play()

            isRunning = true
            DebugLogger.shared.log("🔇 BackgroundEngine: silent audio loop started.")
        } catch {
            DebugLogger.shared.log("❌ BackgroundEngine error: \(error.localizedDescription)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        DebugLogger.shared.log("🔇 BackgroundEngine: audio loop stopped.")
    }
}
