import SwiftUI
import UIKit

// MARK: - TrackpadGestureView
/// A UIKit-backed view that enables advanced multi-touch trackpad gestures (1-finger/2-finger pan and tap).
struct TrackpadGestureView: UIViewRepresentable {
    
    var onMove: (CGPoint) -> Void
    var onScroll: (CGPoint) -> Void
    var onTapLeft: () -> Void
    var onTapRight: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        
        // 1-finger pan (Mouse Move)
        let movePan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMove(_:)))
        movePan.minimumNumberOfTouches = 1
        movePan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(movePan)
        
        // 2-finger pan (Mouse Scroll)
        let scrollPan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleScroll(_:)))
        scrollPan.minimumNumberOfTouches = 2
        scrollPan.maximumNumberOfTouches = 2
        view.addGestureRecognizer(scrollPan)
        
        // 1-finger tap (Left Click)
        let tapLeft = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTapLeft(_:)))
        tapLeft.numberOfTouchesRequired = 1
        view.addGestureRecognizer(tapLeft)
        
        // 2-finger tap (Right Click)
        let tapRight = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTapRight(_:)))
        tapRight.numberOfTouchesRequired = 2
        view.addGestureRecognizer(tapRight)
        
        // Dependency resolution to prevent overlapping gestures
        tapLeft.require(toFail: tapRight)
        tapLeft.require(toFail: movePan)
        tapLeft.require(toFail: scrollPan)
        tapRight.require(toFail: scrollPan)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject {
        var parent: TrackpadGestureView
        
        // Throttle timestamps to prevent flooding the WebSocket
        private var lastMoveTime = Date()
        private var lastScrollTime = Date()
        
        init(_ parent: TrackpadGestureView) {
            self.parent = parent
        }
        
        @objc func handleMove(_ sender: UIPanGestureRecognizer) {
            let now = Date()
            if now.timeIntervalSince(lastMoveTime) > 0.016 { // ~60 FPS
                let translation = sender.translation(in: sender.view)
                if translation != .zero {
                    parent.onMove(translation)
                    sender.setTranslation(.zero, in: sender.view)
                    lastMoveTime = now
                }
            }
        }
        
        @objc func handleScroll(_ sender: UIPanGestureRecognizer) {
            let now = Date()
            if now.timeIntervalSince(lastScrollTime) > 0.032 { // ~30 FPS for scrolling
                let translation = sender.translation(in: sender.view)
                if translation != .zero {
                    parent.onScroll(translation)
                    sender.setTranslation(.zero, in: sender.view)
                    lastScrollTime = now
                }
            }
        }
        
        @objc func handleTapLeft(_ sender: UITapGestureRecognizer) {
            if sender.state == .ended {
                parent.onTapLeft()
            }
        }
        
        @objc func handleTapRight(_ sender: UITapGestureRecognizer) {
            if sender.state == .ended {
                parent.onTapRight()
            }
        }
    }
}
