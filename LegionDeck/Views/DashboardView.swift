import SwiftUI

// MARK: - DashboardView
/// Main telemetry dashboard. Minimalist black/white aesthetic (shadcn inspired).
struct DashboardView: View {

    @ObservedObject var socket: SocketManager
    @State private var showLockAlert = false
    @State private var localVolume: Double = 50.0
    @State private var isDraggingVolume = false
    
    private let feedback = UIImpactFeedbackGenerator(style: .medium)

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
                    mediaSection
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
        .onReceive(socket.$telemetry) { newT in
            if !isDraggingVolume, let v = newT.volume {
                localVolume = Double(v)
            }
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

    // MARK: - Media & Audio
    private var mediaSection: some View {
        let t = socket.telemetry
        return VStack(spacing: 16) {
            Text("Now Playing")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                // Media Info
                HStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t.mediaTitle?.isEmpty == false ? t.mediaTitle! : "Not Playing")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(t.mediaArtist?.isEmpty == false ? t.mediaArtist! : "—")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button {
                            feedback.impactOccurred()
                            socket.send(action: "media_prev")
                        } label: { Image(systemName: "backward.fill").font(.title3).foregroundStyle(.white) }
                        
                        Button {
                            feedback.impactOccurred(intensity: 1.0)
                            socket.send(action: "media_playpause")
                        } label: { Image(systemName: "playpause.fill").font(.title2).foregroundStyle(.white) }
                        
                        Button {
                            feedback.impactOccurred()
                            socket.send(action: "media_next")
                        } label: { Image(systemName: "forward.fill").font(.title3).foregroundStyle(.white) }
                    }
                }
                
                // Volume Slider
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.1.fill")
                        .foregroundStyle(.gray)
                        .font(.caption)
                    
                    Slider(
                        value: $localVolume,
                        in: 0...100,
                        onEditingChanged: { editing in
                            isDraggingVolume = editing
                            if !editing {
                                feedback.impactOccurred()
                                socket.send(payload: ["action": "set_volume", "level": localVolume])
                            }
                        }
                    )
                    .tint(.white)
                    
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.gray)
                        .font(.caption)
                }
            }
            .padding(16)
            .background(Color(white: 0.05), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(white: 0.15), lineWidth: 1))
        }
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
        HStack(spacing: 12) {
            Button {
                feedback.impactOccurred(intensity: 0.7)
                socket.send(action: "secure_lock_pc")
                DebugLogger.shared.log("🔒 Secure Lock PC sent.")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                    Text("Secure Lock")
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.red.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            
            NavigationLink(destination: ViewFinderView(socket: socket)) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                    Text("View Finder")
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
}
