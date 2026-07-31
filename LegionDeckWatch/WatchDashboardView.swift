import SwiftUI

// MARK: - WatchDashboardView
/// Apple Watch Series 8 companion dashboard for LegionDeck.
struct WatchDashboardView: View {

    @EnvironmentObject var session: WatchSessionDelegate

    private var t: WatchTelemetry {
        WatchTelemetry(from: session.telemetry)
    }

    @State private var localVolume: Double = 50.0
    @State private var isSettingVolume = false

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

                // Media Controls
                if !t.mediaTitle.isEmpty {
                    VStack(spacing: 6) {
                        Text(t.mediaTitle)
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                        
                        HStack(spacing: 16) {
                            Button {
                                session.sendCommand(["action": "media_prev"])
                            } label: { Image(systemName: "backward.fill") }
                            .buttonStyle(.plain)
                            
                            Button {
                                session.sendCommand(["action": "media_playpause"])
                            } label: { Image(systemName: "playpause.fill").font(.title3) }
                            .buttonStyle(.plain)
                            
                            Button {
                                session.sendCommand(["action": "media_next"])
                            } label: { Image(systemName: "forward.fill") }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }

                // CPU / GPU row
                HStack(spacing: 8) {
                    WatchMetricCard(label: "CPU", value: t.cpuUsage)
                    WatchMetricCard(label: "GPU", value: t.gpuUsage)
                }
                // RAM / VRAM row
                HStack(spacing: 8) {
                    WatchMetricCard(label: "RAM", value: t.ramUsage)
                    WatchMetricCard(label: "VRAM", value: t.vramUsage)
                }
                // Temps
                HStack(spacing: 12) {
                    WatchTempRow(label: "CPU", temp: t.tempCpu)
                    WatchTempRow(label: "GPU", temp: t.tempGpu)
                }
                .padding(.top, 4)

                // Volume Control
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.gray)
                    Text("Volume \(Int(localVolume))%")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                }
                .padding(.top, 8)

                if !session.telemetry.isEmpty {
                    Text("Updated \(t.ageString)")
                        .font(.system(size: 9))
                        .foregroundStyle(.gray)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle("")
        .focusable()
        .digitalCrownRotation(
            $localVolume,
            from: 0,
            through: 100,
            by: 5,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: localVolume) { newValue in
            session.sendCommand(["action": "set_volume", "level": newValue])
        }
        .onReceive(session.$telemetry) { _ in
            // Don't overwrite if we are actively turning the crown (we can assume ageString prevents jitter)
            if Int(localVolume) != t.volume {
                localVolume = Double(t.volume)
            }
        }
    }
}

// MARK: - Watch Sub-Views

private struct WatchMetricCard: View {
    let label: String
    let value: Int

    private var color: Color {
        value > 80 ? .red : .green
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 4)
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
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct WatchTempRow: View {
    let label: String
    let temp: Int

    private var color: Color {
        temp > 85 ? .red : .green
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "thermometer.medium")
                .font(.system(size: 10))
                .foregroundStyle(.gray)
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
    var volume:    Int = 50
    var mediaTitle: String = ""
    var mediaArtist: String = ""
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
        volume    = dict["volume"]     as? Int ?? 50
        mediaTitle = dict["media_title"] as? String ?? ""
        mediaArtist = dict["media_artist"] as? String ?? ""
        lastUpdate = dict["last_update"] as? TimeInterval ?? 0
    }
}
