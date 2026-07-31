import SwiftUI

// MARK: - DashboardView
/// Main telemetry dashboard. Minimalist black/white aesthetic (shadcn inspired).
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
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    gaugesSection
                    tempSection
                    controlsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
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
            VStack(alignment: .leading, spacing: 4) {
                Text("LegionDeck")
                    .font(.system(size: 24, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                
                HStack(spacing: 6) {
                    Text(socket.connectionState.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(socket.connectionState == .connected ? .green : .red)
                    if let label = socket.telemetry.gpuLabel {
                        Text("·")
                            .foregroundStyle(.gray)
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Gauges Grid
    private var gaugesSection: some View {
        let t = socket.telemetry
        return VStack(spacing: 16) {
            Text("Performance")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                GaugeCard(label: "CPU", value: t.cpuUsage,  icon: "cpu")
                GaugeCard(label: "GPU", value: t.gpuUsage,  icon: "memorychip")
                GaugeCard(label: "RAM", value: t.ramUsage,  icon: "internaldrive")
                GaugeCard(label: "VRAM", value: t.vramUsage, icon: "memorychip.fill")
            }
        }
    }

    // MARK: - Temperature Section
    private var tempSection: some View {
        let t = socket.telemetry
        return VStack(alignment: .leading, spacing: 16) {
            Text("Temperatures")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                TempIndicator(label: "CPU · Ryzen AI 7", temp: t.tempCpu)
                TempIndicator(label: "GPU · RTX 5070",  temp: t.tempGpu)
                if let iGPU = t.tempIgpu, iGPU > 0 {
                    TempIndicator(label: "iGPU · 860M", temp: iGPU)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Controls
    private var controlsSection: some View {
        Button {
            showLockAlert = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                Text("Lock PC")
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(white: 0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
