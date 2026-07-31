import WidgetKit
import SwiftUI

// MARK: - LegionWatchWidget
/// WidgetKit complications for Apple Watch Series 8.
/// Reads from AppGroup UserDefaults written by WatchSessionDelegate.
/// Implements all 4 accessory families for maximum watch face compatibility.

private let appGroupID = "group.com.legiondeck.app"

// MARK: - Timeline Provider
struct LegionTimelineProvider: TimelineProvider {

    typealias Entry = LegionEntry

    func placeholder(in context: Context) -> LegionEntry {
        LegionEntry(date: Date(), cpu: 42, gpu: 65, ram: 55, temp: 71)
    }

    func getSnapshot(in context: Context, completion: @escaping (LegionEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LegionEntry>) -> Void) {
        let current = entry()
        // Return a timeline that expires in 5 minutes (data pushed via WCSession triggers reloads)
        let nextUpdate = Date().addingTimeInterval(5 * 60)
        completion(Timeline(entries: [current], policy: .after(nextUpdate)))
    }

    private func entry() -> LegionEntry {
        let d = UserDefaults(suiteName: appGroupID)
        return LegionEntry(
            date: Date(),
            cpu:  d?.integer(forKey: "cpu_usage")  ?? 0,
            gpu:  d?.integer(forKey: "gpu_usage")  ?? 0,
            ram:  d?.integer(forKey: "ram_usage")  ?? 0,
            temp: d?.integer(forKey: "temp_cpu")   ?? 0
        )
    }
}

// MARK: - Entry
struct LegionEntry: TimelineEntry {
    let date: Date
    let cpu: Int
    let gpu: Int
    let ram: Int
    let temp: Int
}

// MARK: - Widget
@main
struct LegionWatchWidget: Widget {
    let kind = "LegionWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LegionTimelineProvider()) { entry in
            LegionWatchWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("LegionDeck")
        .description("Real-time PC hardware metrics.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline,
        ])
    }
}

// MARK: - Entry View (dispatch per family)
struct LegionWatchWidgetEntryView: View {
    var entry: LegionEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.isLuminanceReduced) var dimmed  // AOD state

    var body: some View {
        switch family {
        case .accessoryCircular:    CircularView(entry: entry, dimmed: dimmed)
        case .accessoryRectangular: RectangularView(entry: entry, dimmed: dimmed)
        case .accessoryCorner:      CornerView(entry: entry, dimmed: dimmed)
        case .accessoryInline:      InlineView(entry: entry)
        default:                    Text("?")
        }
    }
}

// MARK: - accessoryCircular: CPU% ring
private struct CircularView: View {
    let entry: LegionEntry
    let dimmed: Bool

    var body: some View {
        ZStack {
            if !dimmed {
                Circle()
                    .trim(from: 0, to: CGFloat(entry.cpu) / 100.0)
                    .stroke(.cyan, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 1) {
                Text("\(entry.cpu)")
                    .font(.system(size: 18, weight: .bold).monospacedDigit())
                Text("CPU%")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - accessoryRectangular: 4-metric grid
private struct RectangularView: View {
    let entry: LegionEntry
    let dimmed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 9))
                    .foregroundStyle(.cyan)
                Text("LEGION PC")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.cyan)
                    .tracking(0.5)
            }
            HStack(spacing: 10) {
                MetricPair(label: "CPU", value: entry.cpu)
                MetricPair(label: "GPU", value: entry.gpu)
                MetricPair(label: "RAM", value: entry.ram)
                MetricPair(label: "°C",  value: entry.temp)
            }
        }
    }
}

private struct MetricPair: View {
    let label: String
    let value: Int
    var body: some View {
        VStack(spacing: 0) {
            Text("\(value)")
                .font(.system(size: 14, weight: .bold).monospacedDigit())
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - accessoryCorner: GPU arc gauge
private struct CornerView: View {
    let entry: LegionEntry
    let dimmed: Bool

    var body: some View {
        Text("\(entry.gpu)%")
            .font(.system(size: 14, weight: .bold).monospacedDigit())
            .widgetLabel {
                Gauge(value: Double(entry.gpu), in: 0...100) {
                    Text("GPU")
                }
                .tint(.purple)
                .gaugeStyle(.accessoryLinear)
            }
    }
}

// MARK: - accessoryInline: compact text
private struct InlineView: View {
    let entry: LegionEntry
    var body: some View {
        Text("CPU \(entry.cpu)% · GPU \(entry.gpu)% · \(entry.temp)°C")
    }
}
