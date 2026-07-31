import UIKit

// MARK: - ClipboardSync
/// Bidirectional clipboard sync between iOS and Windows.
/// iOS → Windows: polls UIPasteboard.changeCount every 2 seconds.
/// Windows → iOS: called by SocketManager when telemetry.clipboard changes.
@MainActor
final class ClipboardSync {

    static let shared = ClipboardSync()

    private weak var socketManager: SocketManager?
    private var pollingTask: Task<Void, Never>?
    private var lastChangeCount: Int = -1
    private var lastSentText: String = ""
    private var lastReceivedText: String = ""

    var isEnabled: Bool {
        get { 
            if UserDefaults.standard.object(forKey: "clipboard_sync_enabled") == nil { return true }
            return UserDefaults.standard.bool(forKey: "clipboard_sync_enabled") 
        }
        set { UserDefaults.standard.set(newValue, forKey: "clipboard_sync_enabled") }
    }

    private init() {}

    func start(socketManager: SocketManager) {
        self.socketManager = socketManager
        pollingTask?.cancel()
        pollingTask = Task { await pollLoop() }
        DebugLogger.shared.log("📋 Clipboard sync started.")
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        DebugLogger.shared.log("📋 Clipboard sync stopped.")
    }

    // MARK: - iOS → Windows

    private func pollLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
            guard isEnabled else { continue }
            let current = UIPasteboard.general.changeCount
            guard current != lastChangeCount else { continue }
            lastChangeCount = current
            guard let text = UIPasteboard.general.string, !text.isEmpty else { continue }
            guard text != lastSentText, text != lastReceivedText else { continue }
            lastSentText = text
            socketManager?.send(action: "set_clipboard", text: text)
            let preview = String(text.prefix(40)) + (text.count > 40 ? "…" : "")
            DebugLogger.shared.log("📋 Clipboard → Windows: '\(preview)'")
        }
    }

    // MARK: - Windows → iOS
    /// Called by SocketManager whenever a new telemetry frame arrives with a clipboard value.
    func receive(text: String) {
        guard isEnabled else { return }
        guard !text.isEmpty,
              text != lastReceivedText,
              text != lastSentText else { return }
        lastReceivedText = text
        let preview = String(text.prefix(40)) + (text.count > 40 ? "…" : "")
        DebugLogger.shared.log("📋 Clipboard ← Windows: '\(preview)'")
        UIPasteboard.general.string = text
    }
}
