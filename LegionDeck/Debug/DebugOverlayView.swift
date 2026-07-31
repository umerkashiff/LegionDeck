import SwiftUI

// MARK: - DebugOverlayView
/// A floating, draggable, collapsible semi-transparent terminal overlay.
/// Renders over the entire app — crucial for on-device debugging without Xcode.
struct DebugOverlayView: View {

    @ObservedObject private var logger = DebugLogger.shared
    @State private var isExpanded = false
    @State private var offset: CGSize = CGSize(width: 0, height: 200)
    @State private var isDragging = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isExpanded {
                expandedPanel
                    .transition(.scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity))
            }
            pill
        }
        .offset(offset)
        .gesture(
            DragGesture()
                .onChanged { v in
                    isDragging = true
                    offset = CGSize(
                        width: offset.width + v.translation.width,
                        height: offset.height + v.translation.height
                    )
                }
                .onEnded { _ in isDragging = false }
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
        .padding(16)
    }

    // MARK: - Collapsed Pill
    private var pill: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "terminal.fill")
                    .font(.caption)
                Text("\(logger.lines.count)")
                    .font(.caption.monospacedDigit())
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.green)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.green.opacity(0.4), lineWidth: 1))
        }
        .scaleEffect(isDragging ? 0.93 : 1.0)
    }

    // MARK: - Expanded Console Panel
    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Divider().overlay(Color.green.opacity(0.3))
            logList
        }
        .frame(width: 320, height: 260)
        .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.green.opacity(0.15), radius: 10)
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "terminal.fill")
                .foregroundStyle(Color.green)
            Text("LegionDeck Debug Console")
                .font(.caption.monospaced())
                .foregroundStyle(Color.green)
            Spacer()
            Button {
                isExpanded = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.green.opacity(0.7))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.7))
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(logger.lines) { line in
                        Text(line.display)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.green)
                            .textSelection(.enabled)
                            .id(line.id)
                    }
                }
                .padding(8)
            }
            .onChange(of: logger.lines.count) { _, _ in
                if let last = logger.lines.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}
