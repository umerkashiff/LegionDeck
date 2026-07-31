import SwiftUI
import LocalAuthentication

struct AuthOverlayView: View {
    @ObservedObject var socket: SocketManager
    @State private var hasPrompted = false
    
    var body: some View {
        ZStack {
            if socket.isAuthRequested {
                // Blurred background
                Color.black.opacity(0.8)
                    .background(Material.ultraThin)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.yellow)
                        .symbolEffect(.pulse, options: .repeating)
                    
                    if let app = socket.authRequestApp, !app.isEmpty {
                        Text("\(app) is Locked")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    } else if socket.authRequestType == "secure_screen" {
                        Text("Legion PC is Locked")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                    
                    Text("Authenticate to unlock")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    
                    Button {
                        promptAuth()
                    } label: {
                        Text("Use Face ID")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(Color.white, in: Capsule())
                    }
                    .padding(.top, 16)
                    
                    Button {
                        // User can cancel and dismiss on the phone side, but the PC remains locked
                        withAnimation {
                            socket.isAuthRequested = false
                            hasPrompted = false
                        }
                    } label: {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .padding(.top, 8)
                }
                .transition(.opacity.combined(with: .scale))
                .onAppear {
                    if !hasPrompted {
                        hasPrompted = true
                        promptAuth()
                    }
                }
            }
        }
    }
    
    private func promptAuth() {
        let reason = socket.authRequestType == "app_lock" ? 
            "Unlock \(socket.authRequestApp ?? "App") on Legion PC" : 
            "Unlock Legion PC"
            
        FaceIDManager.shared.authenticate(reason: reason) { success, error in
            if success {
                socket.send(payload: [
                    "action": "auth_success",
                    "app": socket.authRequestApp ?? "",
                    "type": socket.authRequestType
                ])
                withAnimation {
                    socket.isAuthRequested = false
                    hasPrompted = false
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                if let error = error {
                    DebugLogger.shared.log("Auth failed: \(error.localizedDescription)")
                }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}
