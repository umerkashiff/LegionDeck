import SwiftUI

// MARK: - DebugOverlayView
/// A floating, draggable, collapsible semi-transparent terminal overlay.
/// Renders over the entire app — crucial for on-device debugging without Xcode.
struct DebugOverlayView: View {

    @ObservedObject private var logger = DebugLogger.shared
    @State private var isExpanded = false
    @State private var offset: CGSize = CGSize(width: 0, height: -60)
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
                Image(systemName: "terminal")
                    .font(.caption)
                Text("\(logger.lines.count)")
                    .font(.caption.monospacedDigit())
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.15))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color(white: 0.3), lineWidth: 1))
        }
        .scaleEffect(isDragging ? 0.95 : 1.0)
    }

    // MARK: - Expanded Console Panel
    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Divider().overlay(Color(white: 0.2))
            logList
        }
        .frame(width: 320, height: 280)
        .background(Color(white: 0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(white: 0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "terminal")
                .foregroundStyle(.gray)
            Text("Debug Console")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
            Spacer()
            Button {
                isExpanded = false
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(white: 0.1))
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(logger.lines) { line in
                        Text(line.display)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(Color(white: 0.8))
                            .textSelection(.enabled)
                            .id(line.id)
                    }
                }
                .padding(10)
            }
            .onChange(of: logger.lines.count) { _, _ in
                if let last = logger.lines.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}
