import SwiftUI

// MARK: - DashboardView
/// Main telemetry dashboard. Gaming dark-neon aesthetic with animated gauges.
struct DashboardView: View {

    @ObservedObject var socket: SocketManager
    @State private var showLockAlert = false

    private let t: TelemetryModel

    init(socket: SocketManager) {
        self.socket = socket
        self.t = socket.telemetry
    }

    var body: some View {
        ZStack {
            // Background
            Color(hex: "#0A0A0F").ignoresSafeArea()
            ParticleBackground()

            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    gaugesSection
                    tempSection
                    controlsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .alert("Lock PC?", isPresented: $showLockAlert) {
            Button("Lock", role: .destructive) {
                socket.send(action: "lock_pc")
                DebugLogger.shared.log("🔒 Lock PC sent.")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will immediately lock your Windows PC.")
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("LEGION DECK")
                    .font(.system(size: 22, weight: .black, design: .default))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#00D4FF"), Color(hex: "#8B5CF6")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .tracking(2)
                HStack(spacing: 6) {
                    ConnectionDot(state: socket.connectionState)
                    Text(socket.connectionState.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                    if let label = socket.telemetry.gpuLabel {
                        Text("·")
                            .foregroundStyle(.white.opacity(0.3))
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Gauges Grid
    private var gaugesSection: some View {
        let t = socket.telemetry
        return VStack(spacing: 16) {
            Text("PERFORMANCE")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.white.opacity(0.3))
                .tracking(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                GaugeCard(label: "CPU", value: t.cpuUsage,  icon: "cpu",          accentColor: Color(hex: "#00D4FF"))
                GaugeCard(label: "GPU", value: t.gpuUsage,  icon: "memorychip",   accentColor: Color(hex: "#8B5CF6"))
                GaugeCard(label: "RAM", value: t.ramUsage,  icon: "internaldrive", accentColor: Color(hex: "#34D399"))
                GaugeCard(label: "VRAM", value: t.vramUsage, icon: "memorychip.fill", accentColor: Color(hex: "#F59E0B"))
            }
        }
        .padding(16)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: - Temperature Section
    private var tempSection: some View {
        let t = socket.telemetry
        return VStack(alignment: .leading, spacing: 12) {
            Text("TEMPERATURES")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.white.opacity(0.3))
                .tracking(3)

            HStack(spacing: 12) {
                TempIndicator(label: "CPU · Ryzen AI 7", temp: t.tempCpu)
                TempIndicator(label: "GPU · RTX 5070",  temp: t.tempGpu)
                if let iGPU = t.tempIgpu, iGPU > 0 {
                    TempIndicator(label: "iGPU · 860M", temp: iGPU)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: - Controls
    private var controlsSection: some View {
        Button {
            showLockAlert = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                Text("Lock PC")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#EF4444"), Color(hex: "#DC2626")],
                    startPoint: .leading, endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Particle Background
private struct ParticleBackground: View {
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<20, id: \.self) { i in
                Circle()
                    .fill(
                        i % 2 == 0
                            ? Color(hex: "#00D4FF").opacity(0.03)
                            : Color(hex: "#8B5CF6").opacity(0.03)
                    )
                    .frame(
                        width: CGFloat.random(in: 60...200),
                        height: CGFloat.random(in: 60...200)
                    )
                    .position(
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: CGFloat.random(in: 0...geo.size.height)
                    )
                    .blur(radius: 30)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
