import SwiftUI

struct ViewFinderView: View {
    @ObservedObject var socket: SocketManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let image = socket.viewfinderImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                    Text("Connecting to PC Viewfinder...")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
            }
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            socket.send(action: "start_viewfinder")
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            socket.send(action: "stop_viewfinder")
            socket.viewfinderImage = nil
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
