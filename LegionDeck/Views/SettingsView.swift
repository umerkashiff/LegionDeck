import SwiftUI

// MARK: - SettingsView
struct SettingsView: View {

    @ObservedObject var socket: SocketManager
    @AppStorage("pc_ip_address")       private var ipAddress = ""
    @AppStorage("clipboard_sync_enabled") private var clipboardEnabled = true
    @AppStorage("debug_overlay_enabled")  private var debugEnabled = true
    @AppStorage("trackpad_sensitivity")   private var trackpadSensitivity: Double = 1.5
    @AppStorage("install_date")        private var installDateRaw = Date().timeIntervalSince1970

    @AppStorage("encryption_key") private var encryptionKey = "LegionDeck_SecretKey_32_Bytes!!!"
    
    @State private var editableIP = ""
    @State private var editableKey = ""
    @FocusState private var isFocused: Bool

    private var daysUntilExpiry: Int {
        let installed = Date(timeIntervalSince1970: installDateRaw)
        let expiry = installed.addingTimeInterval(7 * 24 * 60 * 60)
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            List {
                // ── Connection ────────────────────────────────────────────
                Section {
                    HStack {
                        Image(systemName: "network")
                            .foregroundStyle(.gray)
                            .frame(width: 28)
                        TextField("192.168.x.x", text: $editableIP)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                            .focused($isFocused)
                            .onSubmit { applySettings() }
                            .foregroundStyle(.white)
                    }
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.gray)
                            .frame(width: 28)
                        SecureField("Encryption Key (32-bytes)", text: $editableKey)
                            .focused($isFocused)
                            .onSubmit { applySettings() }
                            .foregroundStyle(.white)
                    }
                    HStack(spacing: 12) {
                        Button {
                            applySettings()
                            socket.connect()
                        } label: {
                            Label("Connect", systemImage: "bolt.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(white: 0.2))
                        .foregroundStyle(.white)
                        .disabled(socket.connectionState == .connecting)

                        Button {
                            socket.disconnect()
                            BackgroundEngine.shared.stop()
                        } label: {
                            Label("Disconnect", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    HStack {
                        Text(socket.connectionState.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("PC Connection")
                }
                .listRowBackground(Color(white: 0.05))

                // ── Features ──────────────────────────────────────────────
                Section {
                    Toggle(isOn: $clipboardEnabled) {
                        Label("Clipboard Sync", systemImage: "doc.on.clipboard")
                    }
                    .tint(.green)
                    .onChange(of: clipboardEnabled) { _, enabled in
                        if enabled {
                            ClipboardSync.shared.isEnabled = true
                        } else {
                            ClipboardSync.shared.isEnabled = false
                        }
                        DebugLogger.shared.log("📋 Clipboard sync: \(enabled ? "on" : "off")")
                    }

                    Toggle(isOn: $debugEnabled) {
                        Label("Debug Overlay", systemImage: "terminal")
                    }
                    .tint(.green)
                    
                    VStack(alignment: .leading) {
                        Text("Trackpad Sensitivity: \(trackpadSensitivity, specifier: "%.1f")x")
                        Slider(value: $trackpadSensitivity, in: 0.5...3.0, step: 0.1)
                            .tint(.white)
                    }
                } header: {
                    Text("Features")
                }
                .listRowBackground(Color(white: 0.05))

                // ── About ────────────────────────────────────────────────
                Section {
                    LabeledContent("App", value: "LegionDeck")
                    LabeledContent("Target", value: "iPhone 16 Pro · iOS 27")
                    LabeledContent("Watch", value: "Series 8 · watchOS 26.5")
                    LabeledContent("Daemon Port", value: ":8765")
                    LabeledContent("Credits", value: "Developed and Designed by Umer Kashif")
                } header: {
                    Text("About")
                }
                .listRowBackground(Color(white: 0.05))
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .onAppear { 
            editableIP = ipAddress 
            editableKey = encryptionKey
        }
    }

    private func applySettings() {
        ipAddress = editableIP.trimmingCharacters(in: .whitespaces)
        encryptionKey = editableKey
        socket.serverIP = ipAddress
        isFocused = false
    }
}
