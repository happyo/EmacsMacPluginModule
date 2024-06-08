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
    private var redViewTag = 999999

    deinit {
        animationTimer?.invalidate()
        redView?.removeFromSuperview()
    }

    func Init(_ env: Environment) throws {
        try env.defun("swift-create-window-info") { (env: Environment) -> WindowInfo in
            return WindowInfo()
        }
        // try env.defun("swift-get-window-info-x") { (model: WindowInfo) in model.x }
        // try env.defun("swift-get-window-info-x") { (model: WindowInfo) in model.x }
        // try env.defun("swift-get-window-info-x") { (model: WindowInfo) in model.x }
        // try env.defun("swift-get-window-info-x") { (model: WindowInfo) in model.x }

        try env.defun("swift-set-window-info-x") { (env: Environment, model: WindowInfo, x: Int?) in
            model.x = x ?? 0
        }

        try env.defun("swift-set-window-info-y") { (env: Environment, model: WindowInfo, y: Int?) in
            model.y = y ?? 0
        }

        try env.defun("swift-set-window-info-width") { (env: Environment, model: WindowInfo, width: Int?) in
            model.width = width ?? 0
        }

        try env.defun("swift-set-window-info-height") { (env: Environment, model: WindowInfo, height: Int?) in
            model.height = height ?? 0
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
            let fixedY = realY + model.height + model.height / 2
      if let _ = self.redView {
                self.scheduleAnimation(toX: fixedX, toY: fixedY)
      } else {
                self.setupRedView(x: fixedX, y: fixedY, cursorWidth: model.width, cursorHeight: model.height)
            }
        }
    }

    private func setupRedView(x: Int, y: Int, cursorWidth: Int, cursorHeight: Int) {
        guard let view = NSApp.mainWindow?.contentView else { return }
        // 检查是否需要更新 redView
        if let existingRedView = view.viewWithTag(redViewTag) {
            self.redView = existingRedView
            
            self.redView?.frame = NSRect(x: x, y: y, width: cursorWidth, height: cursorHeight)
        } else {
            let redView = NSView(frame: NSRect(x: x, y: y, width: cursorWidth, height: cursorHeight))
            redView.wantsLayer = true
            redView.layer?.backgroundColor = NSColor.red.cgColor
            view.addSubview(redView)
            
            redViewTag = redView.tag
            self.redView = redView
        }
    }

    private func scheduleAnimation(toX x: Int, toY y: Int) {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            self.performJellyAnimation(toX: x, toY: y)
        }
    }
    
    private func performJellyAnimation(toX x: Int, toY y: Int) {
        guard let view = NSApp.mainWindow?.contentView, let redView = self.redView else { return }

        self.redView?.alphaValue = 1
        // 获取当前起点和终点
        let startPoint = redView.frame.origin
        let endPoint = CGPoint(x: x, y: y)
        let cursorSize = redView.frame.size
        
        // 创建一个三角形路径
        let trianglePath = createTrianglePath(from: startPoint, to: endPoint, size: cursorSize)
        
        // 创建一个残影视图
        let shadowLayer = CAShapeLayer()
        shadowLayer.path = trianglePath.cgPath
        shadowLayer.fillColor = redView.layer?.backgroundColor
        shadowLayer.opacity = 0.5 // 初始不透明度为 0.5
        view.layer?.addSublayer(shadowLayer)
        
        // 为红色视图添加移动动画
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            redView.animator().setFrameOrigin(endPoint)
        }) {
            self.redView?.alphaValue = 0.3
            shadowLayer.removeFromSuperlayer()
        }
    }

    // 创建三角形路径的辅助方法
    private func createTrianglePath(from startPoint: CGPoint, to endPoint: CGPoint, size: CGSize) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: startPoint)
        
        let topPoint = CGPoint(x: endPoint.x, y: endPoint.y + size.height)
        let bottomPoint = CGPoint(x: endPoint.x, y: endPoint.y)
        
        path.line(to: topPoint)
        path.line(to: bottomPoint)
        path.close()
        
        return path
    }
}

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            @unknown default:
                break
            }
        }
        
        return path
    }
}

func createModule() -> Module { EmacsMacPluginModule() }

