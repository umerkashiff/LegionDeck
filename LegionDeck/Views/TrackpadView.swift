import SwiftUI

struct TrackpadView: View {
    @ObservedObject var socket: SocketManager
    @AppStorage("trackpad_sensitivity") private var trackpadSensitivity: Double = 1.5
    
    // For remote typing
    @State private var textInput: String = ""
    @State private var showKeyboard: Bool = false
    @FocusState private var isKeyboardFocused: Bool
    
    // Feedback
    let feedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // Trackpad Surface
                trackpadSurface
                
                // Live Chat / Typing Box (Visible only when keyboard icon is tapped)
                if showKeyboard {
                    HStack {
                        TextField("Type text to send...", text: $textInput)
                            .focused($isKeyboardFocused)
                            .onAppear {
                                isKeyboardFocused = true
                            }
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                            .onSubmit {
                                sendText()
                            }
                        
                        Button {
                            sendText()
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.blue, in: Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(white: 0.08))
                }
                
                // Bottom App Dock
                bottomDock
            }
        }
    }
    
    private func sendText() {
        guard !textInput.isEmpty else { return }
        socket.send(payload: ["action": "keyboard_type", "text": textInput])
        DebugLogger.shared.log("⌨️ Sent: '\(textInput)'")
        textInput = "" // Clear after sending
        isKeyboardFocused = true // Keep keyboard open for continuous typing
    }
    
    private var trackpadSurface: some View {
        TrackpadGestureView(
            onMove: { delta in
                // Scale movement by sensitivity
                socket.send(payload: ["action": "mouse_move", "dx": delta.x * trackpadSensitivity, "dy": delta.y * trackpadSensitivity])
            },
            onScroll: { delta in
                socket.send(payload: ["action": "mouse_scroll", "dy": -delta.y])
            },
            onTapLeft: {
                feedback.impactOccurred()
                socket.send(payload: ["action": "mouse_click", "button": "left"])
                DebugLogger.shared.log("🖱️ Left Click")
                isKeyboardFocused = false
            },
            onTapRight: {
                feedback.impactOccurred(intensity: 1.0)
                socket.send(payload: ["action": "mouse_click", "button": "right"])
                DebugLogger.shared.log("🖱️ Right Click")
                isKeyboardFocused = false
            },
            onDragBegin: {
                feedback.impactOccurred(intensity: 0.8)
                socket.send(payload: ["action": "mouse_down"])
                DebugLogger.shared.log("👆 Mouse Down (Drag Start)")
                isKeyboardFocused = false
            },
            onDragEnd: {
                feedback.impactOccurred(intensity: 0.5)
                socket.send(payload: ["action": "mouse_up"])
                DebugLogger.shared.log("👆 Mouse Up (Drag End)")
            }
        )
        .background(Color(white: 0.05))
        .overlay(
            HStack {
                Spacer()
                
                // Visual Scroll Zone Indicator
                Rectangle()
                    .fill(
                        LinearGradient(colors: [Color(white: 0.1), .clear], startPoint: .trailing, endPoint: .leading)
                    )
                    .frame(width: 40)
                    .opacity(0.4)
                    .allowsHitTesting(false)
            }
        )
        .overlay(
            VStack {
                Image(systemName: "hand.point.up.left")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(white: 0.15))
                Text("1-Finger: Move / Click\n2-Finger: Scroll / Right-Click\nRight Edge: Scroll")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(white: 0.2))
                    .padding(.top, 8)
            }
        )
    }
    
    private var bottomDock: some View {
        HStack(spacing: 20) {
            appButton(icon: "gamecontroller.fill", app: "steam", color: .white)
            appButton(icon: "message.fill", app: "discord", color: Color(red: 0.35, green: 0.4, blue: 0.95))
            appButton(icon: "safari.fill", app: "chrome", color: .blue)
            appButton(icon: "folder.fill", app: "explorer", color: .yellow)
            
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showKeyboard.toggle()
                }
            } label: {
                Image(systemName: "keyboard")
                    .font(.title3)
                    .foregroundStyle(showKeyboard ? .black : .white)
                    .frame(width: 44, height: 44)
                    .background(showKeyboard ? .white : Color(white: 0.15), in: Circle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.black)
    }
    
    private func appButton(icon: String, app: String, color: Color) -> some View {
        Button {
            feedback.impactOccurred()
            socket.send(payload: ["action": "launch_app", "app": app])
            DebugLogger.shared.log("🚀 Launching \(app.capitalized)")
        } label: {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 50, height: 50)
                .background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
