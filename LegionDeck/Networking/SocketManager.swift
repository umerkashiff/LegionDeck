import Foundation
import Combine
import UIKit

// MARK: - SocketManager
/// Manages the WebSocket connection to the Windows daemon.
/// Automatically reconnects with exponential backoff.
/// Publishes decoded telemetry and connection state for SwiftUI consumption.
@MainActor
final class SocketManager: ObservableObject {

    // MARK: Published
    @Published var telemetry: TelemetryModel = .placeholder
    @Published var connectionState: ConnectionState = .disconnected

    // MARK: Private
    private var task: URLSessionWebSocketTask?
    private var reconnectTask: Task<Void, Never>?
    private var backoffSeconds: Double = 1.0
    private let maxBackoff: Double = 30.0
    private let decoder = JSONDecoder()

    // MARK: AppStorage-backed IP
    var serverIP: String {
        get { UserDefaults.standard.string(forKey: "pc_ip_address") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "pc_ip_address") }
    }

    // MARK: - Connection Lifecycle

    func connect() {
        guard !serverIP.isEmpty else {
            DebugLogger.shared.log("⚠️ No IP address set — open Settings to configure.")
            return
        }
        
        // If already connected/connecting, do not spin up a duplicate connection!
        if connectionState == .connected || connectionState == .connecting {
            return
        }
        
        reconnectTask?.cancel()
        reconnectTask = Task { await connectLoop() }
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        pingTask?.cancel()
        pingTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        connectionState = .disconnected
        backoffSeconds = 1.0
        DebugLogger.shared.log("🔌 Disconnected by user.")
    }

    // MARK: - Private Helpers

    private func connectLoop() async {
        while !Task.isCancelled {
            openConnection()
            
            // Suspend the reconnect loop while we are actively connecting or connected
            while !Task.isCancelled && connectionState != .disconnected {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s poll
            }
            
            guard !Task.isCancelled else { break }
            DebugLogger.shared.log("⏳ Reconnecting in \(Int(backoffSeconds))s…")
            try? await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
            backoffSeconds = min(backoffSeconds * 2, maxBackoff)
        }
    }

    private func openConnection() {
        guard let url = URL(string: "ws://\(serverIP):8765") else {
            DebugLogger.shared.log("❌ Invalid server URL: \(serverIP)")
            return
        }

        connectionState = .connecting
        DebugLogger.shared.log("🔗 Connecting to \(url)…")

        task?.cancel(with: .goingAway, reason: nil)
        let ws = URLSession.shared.webSocketTask(with: url)
        self.task = ws
        ws.resume()

        // Verify the connection actually succeeded before marking as connected
        ws.sendPing { [weak self] error in
            Task { @MainActor in
                guard let self = self else { return }
                if let error = error {
                    DebugLogger.shared.log("❌ Connection failed: \(error.localizedDescription)")
                    self.connectionState = .disconnected
                } else {
                    self.connectionState = .connected
                    self.backoffSeconds = 1.0
                    DebugLogger.shared.log("✅ Connected to \(self.serverIP):8765")
                    
                    // Start receive loop
                    self.receiveMessage()
                    self.startPingTask()
                }
            }
        }
    }
    
    private var pingTask: Task<Void, Never>?
    private var lastPongDate: Date = Date()
    
    private func startPingTask() {
        lastPongDate = Date()
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let self = self else { return }
                
                await MainActor.run {
                    guard self.connectionState == .connected else { return }
                    if Date().timeIntervalSince(self.lastPongDate) > 6.0 {
                        DebugLogger.shared.log("⚠️ Ping timeout. Forcing disconnect.")
                        self.connectionState = .disconnected
                        self.task?.cancel()
                        self.pingTask?.cancel()
                    } else {
                        self.task?.sendPing { error in
                            if error == nil {
                                self.lastPongDate = Date()
                            }
                        }
                    }
                }
            }
        }
    }

    private func receiveMessage() {
        guard let ws = task, connectionState == .connected else { return }
        
        ws.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    Task { @MainActor in self.handleJSON(text) }
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        Task { @MainActor in self.handleJSON(text) }
                    }
                @unknown default:
                    break
                }
                
                // Recursively call to receive the next message
                Task { @MainActor in self.receiveMessage() }
                
            case .failure(let error):
                Task { @MainActor in
                    DebugLogger.shared.log("⚡ WebSocket error: \(error.localizedDescription)")
                    self.connectionState = .disconnected
                }
            }
        }
    }

    @Published var isAuthRequested: Bool = false
    @Published var authRequestApp: String? = nil
    @Published var authRequestType: String = ""
    @Published var viewfinderImage: UIImage? = nil

    private func handleJSON(_ text: String) {
        guard let decryptedText = CryptoService.shared.decrypt(text),
              let data = decryptedText.data(using: .utf8) else { return }
        
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let action = dict["action"] as? String {
            
            if action == "request_auth" {
                let app = dict["app"] as? String
                let type = dict["type"] as? String ?? "secure_screen"
                self.authRequestApp = app
                self.authRequestType = type
                self.isAuthRequested = true
                return
            } else if action == "viewfinder_frame" {
                if let b64 = dict["data"] as? String,
                   let imgData = Data(base64Encoded: b64),
                   let uiImage = UIImage(data: imgData) {
                    self.viewfinderImage = uiImage
                }
                return
            }
        }
        
        do {
            let model = try decoder.decode(TelemetryModel.self, from: data)
            telemetry = model
        } catch {
            // Ignore non-telemetry messages silently
        }
    }

    // MARK: - Send Commands

    /// Send a dictionary payload to the Windows daemon.
    func send(payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let str = String(data: data, encoding: .utf8),
              let encryptedStr = CryptoService.shared.encrypt(str) else { return }
        task?.send(.string(encryptedStr)) { error in
            if let error = error {
                Task { @MainActor in
                    DebugLogger.shared.log("❌ Send error: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Send a simple action to the Windows daemon.
    func send(action: String, text: String? = nil) {
        var dict: [String: Any] = ["action": action]
        if let text { dict["text"] = text }
        send(payload: dict)
    }
}
