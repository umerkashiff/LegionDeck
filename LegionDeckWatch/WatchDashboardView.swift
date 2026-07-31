import SwiftUI

// MARK: - WatchDashboardView
/// Apple Watch Series 8 companion dashboard for LegionDeck.
struct WatchDashboardView: View {

    @EnvironmentObject var session: WatchSessionDelegate

    private var t: WatchTelemetry {
        WatchTelemetry(from: session.telemetry)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Header
                HStack {
                    Image(systemName: "desktopcomputer")
                        .foregroundStyle(.cyan)
                        .font(.caption)
                    Text("LEGION PC")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.cyan)
                        .tracking(1.5)
                    Spacer()
                }

                // CPU / GPU row
                HStack(spacing: 8) {
                    WatchMetricCard(label: "CPU", value: t.cpuUsage, color: .cyan)
                    WatchMetricCard(label: "GPU", value: t.gpuUsage, color: .purple)
                }
                // RAM / VRAM row
                HStack(spacing: 8) {
                    WatchMetricCard(label: "RAM", value: t.ramUsage, color: .green)
                    WatchMetricCard(label: "VRAM", value: t.vramUsage, color: .orange)
                }
                // Temps
                HStack(spacing: 12) {
                    WatchTempRow(label: "CPU", temp: t.tempCpu)
                    WatchTempRow(label: "GPU", temp: t.tempGpu)
                }
                .padding(.top, 4)

                if !session.telemetry.isEmpty {
                    Text("Updated \(t.ageString)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle("")
    }
}

// MARK: - Watch Sub-Views

private struct WatchMetricCard: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(value) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(value)%")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .frame(width: 52, height: 52)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct WatchTempRow: View {
    let label: String
    let temp: Int

    private var color: Color {
        temp < 70 ? .green : temp < 85 ? .yellow : .red
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "thermometer.medium")
                .font(.system(size: 10))
                .foregroundStyle(color)
            Text("\(label) \(temp)°")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Watch Telemetry Helper
private struct WatchTelemetry {
    var cpuUsage:  Int = 0
    var gpuUsage:  Int = 0
    var ramUsage:  Int = 0
    var vramUsage: Int = 0
    var tempCpu:   Int = 0
    var tempGpu:   Int = 0
    var lastUpdate: TimeInterval = 0

    var ageString: String {
        let age = Int(Date().timeIntervalSince1970 - lastUpdate)
        if age < 10 { return "now" }
        return "\(age)s ago"
    }

    init(from dict: [String: Any]) {
        cpuUsage  = dict["cpu_usage"]  as? Int ?? 0
        gpuUsage  = dict["gpu_usage"]  as? Int ?? 0
        ramUsage  = dict["ram_usage"]  as? Int ?? 0
        vramUsage = dict["vram_usage"] as? Int ?? 0
        tempCpu   = dict["temp_cpu"]   as? Int ?? 0
        tempGpu   = dict["temp_gpu"]   as? Int ?? 0
        lastUpdate = dict["last_update"] as? TimeInterval ?? 0
    }
}
