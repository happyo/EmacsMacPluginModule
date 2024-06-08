// The Swift Programming Language
// https://docs.swift.org/swift-book
import AppKit
import EmacsSwiftModule

class WindowInfo: OpaquelyEmacsConvertible {
    var x: Int = 0
    var y: Int = 0
    var width: Int = 0
    var height: Int = 0

    init() {}

    init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

class EmacsMacPluginModule: Module {
    let isGPLCompatible = true

    var env: Environment?
    var redView: NSView? = nil
    var animationTimer: Timer? = nil
    var lastWindowInfo: WindowInfo? = nil

    func Init(_ env: Environment) throws {
        try env.defun("swift-create-window-info") { (env: Environment) -> WindowInfo in
            return WindowInfo()
        }
        // try env.defun("swift-get-window-info-x") { (model: WindowInfo) in model.x }
        // try env.defun("swift-get-window-info-x") { (model: WindowInfo) in model.x }
        // try env.defun("swift-get-window-info-x") { (model: WindowInfo) in model.x }
        // try env.defun("swift-get-window-info-x") { (model: WindowInfo) in model.x }

        try env.defun("swift-set-window-info-x") { (env: Environment, model: WindowInfo, x: Int) in
            model.x = x
        }

        try env.defun("swift-set-window-info-y") { (env: Environment, model: WindowInfo, y: Int) in
            model.y = y
        }

        try env.defun("swift-set-window-info-width") { (env: Environment, model: WindowInfo, width: Int) in
            model.width = width
        }

        try env.defun("swift-set-window-info-height") { (env: Environment, model: WindowInfo, height: Int) in
            model.height = height
        }

        try env.defun("macos-module--clear-window-info") { (env: Environment) in
            self.redView?.removeFromSuperview()
        }
        
        try env.defun(
            "macos-module--update-window-info",
            with: """
            Update the window information.
            """
        ) { (env: Environment, model: WindowInfo) in
            guard let view = NSApp.mainWindow?.contentView else { return }
            
            let realX = model.x
            let realY = Int(view.bounds.height) - model.y
            
            let fixedX = realX
            let fixedY = realY + model.height
            if let _ = self.redView {
                self.scheduleAnimation(toX: fixedX, toY: fixedY)
            } else {
                self.setupRedView(x: fixedX, y: fixedY, cursorWidth: model.width, cursorHeight: model.height)
            }
        }
        
        try env.defun("macos-module--clear-window-info") { (env: Environment) in
            self.clearAnimations()
        }
    }

    private func setupRedView(x: Int, y: Int, cursorWidth: Int, cursorHeight: Int) {
        guard let view = NSApp.mainWindow?.contentView else { return }
        let redView = NSView(frame: NSRect(x: x, y: y, width: cursorWidth, height: cursorHeight))
        redView.wantsLayer = true
        redView.layer?.backgroundColor = NSColor.red.cgColor
        view.addSubview(redView)
        self.redView = redView
        self.lastWindowInfo = WindowInfo(x: x, y: y, width: cursorWidth, height: cursorHeight)
    }

    private func scheduleAnimation(toX x: Int, toY y: Int) {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            self.performJellyAnimation(toX: x, toY: y)
        }
    }
    
    private func performJellyAnimation(toX x: Int, toY y: Int) {
        guard let view = NSApp.mainWindow?.contentView, let redView = self.redView else { return }
        let springAnimation = CASpringAnimation(keyPath: "position")
        springAnimation.damping = 5.0 // Adjust damping to control the "bounciness"
        springAnimation.stiffness = 100.0 // Adjust stiffness, higher values make the animation start faster
        springAnimation.mass = 1.0 // Mass of the object, affecting the spring animation
        springAnimation.initialVelocity = 0.0 // Initial velocity of the animation
        springAnimation.fromValue = NSValue(point: redView.frame.origin)
        springAnimation.toValue = NSValue(point: CGPoint(x: x, y: y))
        springAnimation.duration = springAnimation.settlingDuration
    
        redView.layer?.add(springAnimation, forKey: "position")
        redView.frame.origin = CGPoint(x: x, y: y) // Update final position to avoid snap-back
    }

    func clearAnimations() {
        animationTimer?.invalidate()
        animationTimer = nil
        redView?.layer?.removeAllAnimations()
        redView?.removeFromSuperview()
        redView = nil
    }

    

}

func createModule() -> Module { EmacsMacPluginModule() }

