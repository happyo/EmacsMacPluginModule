// The Swift Programming Language
// https://docs.swift.org/swift-book
import AppKit
import EmacsSwiftModule

class EmacsMacPluginModule: Module {
    let isGPLCompatible = true

    var env: Environment?
    var cursorView: NSView? = nil
    var animationTimer: Timer? = nil
    private var cursorViewTag = 999999
    private var cursorColor: NSColor = .red
    private var shadowOpacity: Double = 0.8

    deinit {
        animationTimer?.invalidate()
        cursorView?.removeFromSuperview()
    }

    func Init(_ env: Environment) throws {
        try env.defun("swift-create-window-info") { (env: Environment) -> NSWindowInfoModel in
            return NSWindowInfoModel()
        }

        try env.defun("swift-set-window-info-x") { (env: Environment, model: NSWindowInfoModel, x: Int?) in
            model.x = x ?? 0
        }

        try env.defun("swift-set-window-info-y") { (env: Environment, model: NSWindowInfoModel, y: Int?) in
            model.y = y ?? 0
        }

        try env.defun("swift-set-window-info-width") { (env: Environment, model: NSWindowInfoModel, width: Int?) in
            model.width = width ?? 0
        }

        try env.defun("swift-set-window-info-height") { (env: Environment, model: NSWindowInfoModel, height: Int?) in
            model.height = height ?? 0
        }

        try env.defun("macos-module--clear-window-info") { (env: Environment) in
            self.cursorView?.removeFromSuperview()
        }

        try env.defun("swift-set-cursor-color") { (env: Environment, colorString: String) in
            if let color = NSColor(hexString: colorString) {
                self.cursorColor = color
                if let v = self.cursorView {
                    v.layer?.backgroundColor = color.cgColor
                }
            }
        }

        try env.defun("swift-set-shadow-opacity") { (env: Environment, opacity: Double) in
            self.shadowOpacity = opacity
        }
        
        try env.defun(
            "macos-module--update-window-info",
            with: """
            Update the window information.
            """
        ) { (env: Environment, model: NSWindowInfoModel) in
      guard let view = NSApp.mainWindow?.contentView else { return }
            let realX = model.x
            let realY = Int(view.bounds.height) - model.y
            
            let fixedX = realX
            let fixedY = realY + model.height + model.height / 2
      if let _ = self.cursorView {
                self.scheduleAnimation(toX: fixedX, toY: fixedY)
      } else {
                self.setupRedView(x: fixedX, y: fixedY, cursorWidth: model.width, cursorHeight: model.height)
            }
        }
    }

    private func setupRedView(x: Int, y: Int, cursorWidth: Int, cursorHeight: Int) {
        guard let view = NSApp.mainWindow?.contentView else { return }
        // 检查是否需要更新 cursorView
        if let existingRedView = view.viewWithTag(cursorViewTag) {
            self.cursorView = existingRedView
            
            self.cursorView?.frame = NSRect(x: x, y: y, width: cursorWidth, height: cursorHeight)
        } else {
            let cursorView = NSView(frame: NSRect(x: x, y: y, width: cursorWidth, height: cursorHeight))
            cursorView.wantsLayer = true
            cursorView.layer?.backgroundColor = self.cursorColor.cgColor
            view.addSubview(cursorView)
            
            cursorViewTag = cursorView.tag
            self.cursorView = cursorView
        }
    }

    private func scheduleAnimation(toX x: Int, toY y: Int) {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            self.performJellyAnimation(toX: x, toY: y)
        }
    }
    
    private func performJellyAnimation(toX x: Int, toY y: Int) {
        guard let view = NSApp.mainWindow?.contentView, let cursorView = self.cursorView else { return }

        self.cursorView?.alphaValue = 1
        // 获取当前起点和终点
        let startPoint = cursorView.frame.origin
        let endPoint = CGPoint(x: x, y: y)
        let cursorSize = cursorView.frame.size
        
        // 创建一个三角形路径
        let trianglePath = createTrianglePath(from: startPoint, to: endPoint, size: cursorSize)
        
        // 创建一个残影视图
        let shadowLayer = CAShapeLayer()
        shadowLayer.path = trianglePath.cgPath
        shadowLayer.fillColor = cursorView.layer?.backgroundColor
        shadowLayer.opacity = Float(self.shadowOpacity)
        view.layer?.addSublayer(shadowLayer)
        
        // 为红色视图添加移动动画
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            cursorView.animator().setFrameOrigin(endPoint)
        }) {
            self.cursorView?.alphaValue = 0
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

func createModule() -> Module { EmacsMacPluginModule() }

