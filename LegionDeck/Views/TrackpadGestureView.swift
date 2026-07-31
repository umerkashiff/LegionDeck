import SwiftUI
import UIKit

// MARK: - TrackpadGestureView
/// A UIKit-backed view that enables advanced multi-touch trackpad gestures (1-finger/2-finger pan and tap).
struct TrackpadGestureView: UIViewRepresentable {
    
    var onMove: (CGPoint) -> Void
    var onScroll: (CGPoint) -> Void
    var onTapLeft: () -> Void
    var onTapRight: () -> Void
    var onDragBegin: () -> Void
    var onDragEnd: () -> Void
    
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
        
        // Touch and Hold (Drag & Drop)
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        longPress.delegate = context.coordinator
        view.addGestureRecognizer(longPress)
        
        movePan.delegate = context.coordinator
        scrollPan.delegate = context.coordinator
        tapLeft.delegate = context.coordinator
        tapRight.delegate = context.coordinator
        
        // Dependency resolution to prevent overlapping gestures
        tapLeft.require(toFail: tapRight)
        tapLeft.require(toFail: scrollPan)
        tapRight.require(toFail: scrollPan)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: TrackpadGestureView
        
        // Throttle timestamps to prevent flooding the WebSocket
        private var lastMoveTime = Date()
        private var lastScrollTime = Date()
        
        init(_ parent: TrackpadGestureView) {
            self.parent = parent
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow pan and long press to work simultaneously for drag and drop
            if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UILongPressGestureRecognizer {
                return true
            }
            if gestureRecognizer is UILongPressGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            }
            return false
        }
        
        private var isEdgeScrolling = false
        
        @objc func handleMove(_ sender: UIPanGestureRecognizer) {
            guard let view = sender.view else { return }
            
            if sender.state == .began {
                let loc = sender.location(in: view)
                isEdgeScrolling = loc.x > view.bounds.width - 60
            }
            
            let now = Date()
            let translation = sender.translation(in: view)
            
            if isEdgeScrolling {
                if now.timeIntervalSince(lastScrollTime) > 0.032 {
                    if translation != .zero {
                        parent.onScroll(CGPoint(x: 0, y: translation.y))
                        sender.setTranslation(.zero, in: view)
                        lastScrollTime = now
                    }
                }
            } else {
                if now.timeIntervalSince(lastMoveTime) > 0.016 { // ~60 FPS
                    if translation != .zero {
                        parent.onMove(translation)
                        sender.setTranslation(.zero, in: view)
                        lastMoveTime = now
                    }
                }
            }
            
            if sender.state == .ended || sender.state == .cancelled {
                isEdgeScrolling = false
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
        
        @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
            if sender.state == .began {
                parent.onDragBegin()
            } else if sender.state == .ended || sender.state == .cancelled || sender.state == .failed {
                parent.onDragEnd()
            }
        }
    }
}
