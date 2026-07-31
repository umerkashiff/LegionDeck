import SwiftUI

struct TrackpadView: View {
    @ObservedObject var socket: SocketManager
    
    // For mouse movement delta
    @State private var lastLocation: CGPoint? = nil
    
    // For remote typing
    @State private var textInput: String = ""
    @FocusState private var isKeyboardFocused: Bool
    
    // Feedback
    let feedback = UIImpactFeedbackGenerator(style: .light)
    
    // Throttle timestamp
    @State private var lastSendTime = Date()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Invisible text field for capturing keystrokes
                TextField("", text: $textInput)
                    .focused($isKeyboardFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .onChange(of: textInput) { _, newValue in
                        if let lastChar = newValue.last {
                            socket.send(payload: ["action": "keyboard_type", "text": String(lastChar)])
                        } else if newValue.isEmpty {
                            // Backspace was pressed (we just reset the string to avoid length buildup)
                            socket.send(payload: ["action": "keyboard_press", "key": "backspace"])
                        }
                        // Reset string so we always capture new typing without huge string buildup
                        if textInput.count > 5 {
                            textInput = String(textInput.suffix(1))
                        }
                    }
                
                // Trackpad Surface
                trackpadSurface
                
                // Bottom App Dock
                bottomDock
            }
        }
        .onAppear {
            textInput = " " // Seed with space so backspace registers
        }
    }
    
    private var trackpadSurface: some View {
        Rectangle()
            .fill(Color(white: 0.05))
            .overlay(
                VStack {
                    Image(systemName: "hand.point.up.left")
                        .font(.system(size: 40))
                        .foregroundStyle(Color(white: 0.15))
                    Text("Drag to move • Tap to click")
                        .font(.caption)
                        .foregroundStyle(Color(white: 0.2))
                        .padding(.top, 8)
                }
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if let last = lastLocation {
                            let now = Date()
                            if now.timeIntervalSince(lastSendTime) > 0.016 {
                                let dx = value.location.x - last.x
                                let dy = value.location.y - last.y
                                socket.send(payload: ["action": "mouse_move", "dx": dx * 1.5, "dy": dy * 1.5])
                                lastSendTime = now
                                lastLocation = value.location
                            }
                        } else {
                            lastLocation = value.location
                        }
                    }
                    .onEnded { _ in
                        lastLocation = nil
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 1)
                    .onEnded {
                        feedback.impactOccurred()
                        socket.send(payload: ["action": "mouse_click", "button": "left"])
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
                isKeyboardFocused.toggle()
                if isKeyboardFocused { textInput = " " }
            } label: {
                Image(systemName: "keyboard")
                    .font(.title3)
                    .foregroundStyle(isKeyboardFocused ? .black : .white)
                    .frame(width: 44, height: 44)
                    .background(isKeyboardFocused ? .white : Color(white: 0.15), in: Circle())
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
        } label: {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 50, height: 50)
                .background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
