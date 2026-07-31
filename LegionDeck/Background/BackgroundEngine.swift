import AVFoundation

// MARK: - BackgroundEngine
/// Keeps the app process alive in the background using a silent audio loop.
/// This prevents iOS from suspending the WebSocket connection when the screen
/// is off or the user switches apps.
///
/// Requires Info.plist: UIBackgroundModes = [audio]
@MainActor
final class BackgroundEngine {

    static let shared = BackgroundEngine()

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var isRunning = false

    private init() {}

    func start() {
        guard !isRunning else { return }

        do {
            // Configure audio session for background playback, mixing with other audio
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)

            engine = AVAudioEngine()
            playerNode = AVAudioPlayerNode()
            
            guard let engine = engine, let playerNode = playerNode else { return }

            engine.attach(playerNode)

            // Create a standard format
            guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else { return }
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)

            try engine.start()

            // Create a 1-second silent buffer programmatically (avoids needing an mp3 file)
            let frameCount = AVAudioFrameCount(format.sampleRate)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            buffer.frameLength = frameCount

            if let floatChannelData = buffer.floatChannelData {
                for i in 0..<Int(frameCount) {
                    floatChannelData[0][i] = 0.0 // True silence
                }
            }

            // Play on infinite loop
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            playerNode.play()

            isRunning = true
            DebugLogger.shared.log("🔇 BackgroundEngine: Programmatic silent audio loop started.")
        } catch {
            DebugLogger.shared.log("❌ BackgroundEngine error: \(error.localizedDescription)")
        }
    }

    func stop() {
        playerNode?.stop()
        engine?.stop()
        playerNode = nil
        engine = nil
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        DebugLogger.shared.log("🔇 BackgroundEngine: audio loop stopped.")
    }
}
