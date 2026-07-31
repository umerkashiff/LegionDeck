import SwiftUI

// MARK: - SettingsView
struct SettingsView: View {

    @ObservedObject var socket: SocketManager
    @AppStorage("pc_ip_address")       private var ipAddress = ""
    @AppStorage("clipboard_sync_enabled") private var clipboardEnabled = true
    @AppStorage("debug_overlay_enabled")  private var debugEnabled = true
    @AppStorage("install_date")        private var installDateRaw = Date().timeIntervalSince1970

    @State private var editableIP = ""
    @FocusState private var ipFocused: Bool

    private var daysUntilExpiry: Int {
        let installed = Date(timeIntervalSince1970: installDateRaw)
        let expiry = installed.addingTimeInterval(7 * 24 * 60 * 60)
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0)
    }

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0F").ignoresSafeArea()

            List {
                // ── Connection ────────────────────────────────────────────
                Section {
                    HStack {
                        Image(systemName: "network")
                            .foregroundStyle(.cyan)
                            .frame(width: 28)
                        TextField("192.168.x.x", text: $editableIP)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                            .focused($ipFocused)
                            .onSubmit { applyIP() }
                            .foregroundStyle(.white)
                    }
                    HStack(spacing: 12) {
                        Button {
                            applyIP()
                            socket.connect()
                        } label: {
                            Label("Connect", systemImage: "bolt.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .disabled(socket.connectionState == .connecting)

                        Button {
                            socket.disconnect()
                        } label: {
                            Label("Disconnect", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    HStack {
                        ConnectionDot(state: socket.connectionState)
                        Text(socket.connectionState.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("PC Connection")
                }
                .listRowBackground(Color.white.opacity(0.05))

                // ── Features ──────────────────────────────────────────────
                Section {
                    Toggle(isOn: $clipboardEnabled) {
                        Label("Clipboard Sync", systemImage: "doc.on.clipboard")
                    }
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
                } header: {
                    Text("Features")
                }
                .listRowBackground(Color.white.opacity(0.05))

                // ── Signing Status ────────────────────────────────────────
                Section {
                    HStack {
                        Image(systemName: daysUntilExpiry > 2 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(daysUntilExpiry > 2 ? .green : .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("IPA Signing Expiry")
                                .font(.body)
                                .foregroundStyle(.white)
                            Text(daysUntilExpiry > 0
                                 ? "\(daysUntilExpiry) day(s) remaining — re-sign via AltStore"
                                 : "Expired — re-sign with AltStore now")
                                .font(.caption)
                                .foregroundStyle(daysUntilExpiry > 0 ? Color.secondary : Color.red)
                        }
                    }
                    Button("Reset Install Date") {
                        installDateRaw = Date().timeIntervalSince1970
                    }
                    .foregroundStyle(.cyan)
                } header: {
                    Text("AltStore Signing (Free Account)")
                } footer: {
                    Text("Free Apple ID sideloads expire after 7 days. Keep AltServer running on your PC over Wi-Fi for auto-refresh.")
                }
                .listRowBackground(Color.white.opacity(0.05))

                // ── About ────────────────────────────────────────────────
                Section {
                    LabeledContent("App", value: "LegionDeck")
                    LabeledContent("Target", value: "iPhone 16 Pro · iOS 27")
                    LabeledContent("Watch", value: "Series 8 · watchOS 26.5")
                    LabeledContent("Daemon Port", value: ":8765")
                } header: {
                    Text("About")
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .onAppear { editableIP = ipAddress }
    }

    private func applyIP() {
        ipAddress = editableIP.trimmingCharacters(in: .whitespaces)
        socket.serverIP = ipAddress
        ipFocused = false
    }
}
