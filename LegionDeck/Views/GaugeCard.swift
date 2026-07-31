import SwiftUI

// MARK: - GaugeCard
/// Minimalist horizontal progress bar for metrics.
struct GaugeCard: View {
    let label: String
    let value: Int          // 0–100
    let icon: String

    @State private var animatedValue: Double = 0

    private var intensityColor: Color {
        value > 80 ? .red : .green
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.gray)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(value)%")
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(intensityColor)
                        .frame(width: max(0, geo.size.width * CGFloat(animatedValue) / 100.0))
                }
            }
            .frame(height: 8)
            .animation(.spring(response: 0.5, dampingFraction: 1.0), value: animatedValue)
            .onChange(of: Double(value)) { _, newVal in
                animatedValue = newVal
            }
            .onAppear { animatedValue = Double(value) }
        }
    }
}

// MARK: - TempIndicator
struct TempIndicator: View {
    let label: String
    let temp: Int

    private var color: Color {
        temp > 85 ? .red : .green
    }

    var body: some View {
        HStack {
            Image(systemName: "thermometer.medium")
                .foregroundStyle(.gray)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            Text("\(temp)°C")
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ConnectionDot
struct ConnectionDot: View {
    let state: ConnectionState

    private var color: Color {
        switch state {
        case .connected:    return .green
        case .connecting:   return .gray
        case .disconnected: return .red
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}
