import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - LegionActivityWidget
/// Dynamic Island + Lock Screen Live Activity for LegionDeck.
/// Shows real-time CPU, GPU, RAM, VRAM usage and temperatures.
@main
struct LegionActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LegionActivityAttributes.self) { context in
            // ── Lock Screen / StandBy Banner ───────────────────────────────
            LockScreenBannerView(state: context.state, pcName: context.attributes.pcName)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // ── Expanded Dynamic Island ────────────────────────────────
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        IslandMetricRow(label: "CPU", value: context.state.cpuUsage, unit: "%", icon: "cpu")
                        IslandMetricRow(label: "RAM", value: context.state.ramUsage, unit: "%", icon: "memorychip")
                    }
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        IslandMetricRow(label: "GPU", value: context.state.gpuUsage, unit: "%", icon: "rectangle.3.group", isTrailing: true)
                        IslandMetricRow(label: "VRAM", value: context.state.vramUsage, unit: "%", icon: "memorychip.fill", isTrailing: true)
                    }
                    .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        HStack(spacing: 16) {
                            TempBadge(label: "CPU", temp: context.state.tempCpu)
                            TempBadge(label: "GPU", temp: context.state.tempGpu)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(context.attributes.pcName)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.8))
                                Text("Dev by Umer Kashif")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        }
                        
                        if let title = context.state.mediaTitle, !title.isEmpty {
                            HStack {
                                Image(systemName: "music.note")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.gray)
                                Text("\(title) · \(context.state.mediaArtist ?? "")")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Spacer()
                                if let vol = context.state.volume {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.gray)
                                    Text("\(vol)%")
                                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                            .background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }

            } compactLeading: {
                // ── Compact Left: CPU% ─────────────────────────────────────
                HStack(spacing: 3) {
                    Image(systemName: "cpu")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.gray)
                    Text("\(context.state.cpuUsage)%")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(metricColor(context.state.cpuUsage))
                        .contentTransition(.numericText())
                }
                .padding(.leading, 4)

            } compactTrailing: {
                // ── Compact Right: GPU% ────────────────────────────────────
                HStack(spacing: 3) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.gray)
                    Text("\(context.state.gpuUsage)%")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(metricColor(context.state.gpuUsage))
                        .contentTransition(.numericText())
                }
                .padding(.trailing, 4)

            } minimal: {
                // ── Minimal (when two Live Activities compete) ─────────────
                let peak = max(context.state.cpuUsage, context.state.gpuUsage)
                ZStack {
                    Circle()
                        .trim(from: 0, to: CGFloat(peak) / 100.0)
                        .stroke(metricColor(peak), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(peak)")
                        .font(.system(size: 9, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                }
                .frame(width: 22, height: 22)
            }
        }
    }
}

// MARK: - Lock Screen Banner
private struct LockScreenBannerView: View {
    let state: LegionActivityAttributes.ContentState
    let pcName: String

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "desktopcomputer")
                    .foregroundStyle(.white)
                Text(pcName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("LegionDeck")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    Text("Dev by Umer Kashif")
                        .font(.system(size: 8))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }

            HStack(spacing: 12) {
                MetricBar(label: "CPU", value: state.cpuUsage)
                MetricBar(label: "GPU", value: state.gpuUsage)
                MetricBar(label: "RAM", value: state.ramUsage)
                MetricBar(label: "VRAM", value: state.vramUsage)
            }

            HStack(spacing: 20) {
                TempBadge(label: "CPU", temp: state.tempCpu)
                TempBadge(label: "GPU", temp: state.tempGpu)
                Spacer()
            }
        }
        .padding(12)
    }
}

// MARK: - Reusable Sub-Views

private struct IslandMetricRow: View {
    let label: String
    let value: Int
    let unit: String
    let icon: String
    var isTrailing = false

    var body: some View {
        HStack(spacing: 4) {
            if isTrailing { Spacer() }
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.gray)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.gray)
            Text("\(value)\(unit)")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(metricColor(value))
                .contentTransition(.numericText())
            if !isTrailing { Spacer() }
        }
    }
}

private struct MetricBar: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 3) {
            Text("\(value)%")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(metricColor(value))
                .contentTransition(.numericText())
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(white: 0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(metricColor(value))
                        .frame(height: max(0, geo.size.height * CGFloat(value) / 100.0))
                }
            }
            .frame(width: 20, height: 30)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.gray)
        }
    }
}

private struct TempBadge: View {
    let label: String
    let temp: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "thermometer.medium")
                .font(.system(size: 9))
                .foregroundStyle(.gray)
            Text("\(label) \(temp)°C")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(tempColor(temp))
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Color Helpers

private func metricColor(_ value: Int) -> Color {
    value > 80 ? .red : .green
}

private func tempColor(_ temp: Int) -> Color {
    temp > 85 ? .red : .green
}
