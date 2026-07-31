import SwiftUI

// MARK: - GaugeCard
/// Reusable animated arc gauge with label, used for CPU/GPU/RAM/VRAM.
struct GaugeCard: View {
    let label: String
    let value: Int          // 0–100
    let icon: String
    let accentColor: Color

    @State private var animatedValue: Double = 0

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Track ring
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 6)

                // Value arc
                Circle()
                    .trim(from: 0, to: animatedValue / 100.0)
                    .stroke(
                        accentColor.gradient,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: accentColor.opacity(0.5), radius: 4)

                // Center content
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(accentColor)
                    Text("\(value)%")
                        .font(.system(size: 18, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
            }
            .frame(width: 80, height: 80)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animatedValue)
            .onChange(of: Double(value)) { _, newVal in
                animatedValue = newVal
            }
            .onAppear { animatedValue = Double(value) }

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - TempIndicator
struct TempIndicator: View {
    let label: String
    let temp: Int

    private var color: Color {
        switch temp {
        case 0..<70:  return .green
        case 70..<85: return .yellow
        default:      return .red
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "thermometer.medium")
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Text("\(temp)°C")
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - ConnectionDot
struct ConnectionDot: View {
    let state: ConnectionState
    @State private var pulsing = false

    private var color: Color {
        switch state {
        case .connected:    return .green
        case .connecting:   return .orange
        case .disconnected: return .red
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 16, height: 16)
                .scaleEffect(pulsing ? 1.8 : 1.0)
                .opacity(pulsing ? 0 : 1)
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulsing = (state == .connected)
            }
        }
        .onChange(of: state) { _, s in
            pulsing = (s == .connected)
        }
    }
}
