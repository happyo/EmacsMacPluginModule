//
//  Created by belyenochi on 2024/06/11.
//
import AppKit
import EmacsSwiftModule

class CursorPlugin: BasePlugin {
    var cursorView: NSView? = nil
    var animationTimer: Timer? = nil
    private var cursorViewTag = 999999
    private var cursorColor: NSColor = .red
    private var shadowOpacity: Double = 0.8

    deinit {
        animationTimer?.invalidate()
        cursorView?.removeFromSuperview()
    }
    
    public override func initFunctions(_ env: Environment) throws {
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

        try env.defun("swift-test-print-window-info") { (env: Environment, x: Int, y: Int) in
            guard let window = NSApp.mainWindow, let screen = NSScreen.main else {
                try env.funcall("message", with: "No main window found")
                return
            }
    
            let windowFrame = window.frame
            let contentFrame = window.contentRect(forFrameRect: windowFrame)
            let screenHeight = screen.frame.height

            let windowInfo = """
    Window Frame: \(windowFrame)
    Content Frame: \(contentFrame)
    Screen Height: \(screenHeight)
    """
    
            try env.funcall("message", with: windowInfo)

            let locationInfo = """
             x: \(x), y: \(y)
            """
            try env.funcall("message", with: locationInfo)

            let relativePoint = FrameHelper.relativePoint(from: NSPoint(x: x, y: y), window: window, screen: screen)

            let fixedLocationInfo = """
             fixed x: \(relativePoint.x), fixed y: \(relativePoint.y)
            """

            try env.funcall("message", with: fixedLocationInfo)

            let fixedView = NSView(frame: NSRect(x: relativePoint.x, y: relativePoint.y, width: 5, height: 5))
            fixedView.wantsLayer = true
            fixedView.layer?.backgroundColor = NSColor.red.cgColor

            window.contentView?.addSubview(fixedView)
        }
        
        try env.defun(
            "macos-module--update-window-info",
            with: """
            Update the window information.
            """
        ) { (env: Environment, model: NSWindowInfoModel) in
            guard let window = NSApp.mainWindow, let screen = NSScreen.main else {
                try env.funcall("message", with: "No main window found")
                return
            }

            let relativePoint = FrameHelper.relativePoint(from: NSPoint(x: model.x, y: model.y), window: window, screen: screen)

            let fixedX = Int(relativePoint.x)
            let fixedY = Int(relativePoint.y) - model.height
            
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
            cursorView.layer?.cornerRadius = 4
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

        // Calculate direction vector
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y

        if abs(dx) > abs(dy) { // Horizontal direction
            if dx > 0 { // Right direction
                let topPoint = CGPoint(x: endPoint.x, y: endPoint.y + size.height)
                let bottomPoint = CGPoint(x: endPoint.x, y: endPoint.y)
                let fixedStartPoint = startPoint
                path.move(to: fixedStartPoint)
        
                path.line(to: topPoint)
                path.line(to: bottomPoint)
            } else { // Left direction
                let topPoint = CGPoint(x: endPoint.x + size.width, y: endPoint.y + size.height)
                let bottomPoint = CGPoint(x: endPoint.x + size.width, y: endPoint.y)

                let fixedStartPoint = NSPoint(x: startPoint.x + size.width, y: startPoint.y)
                path.move(to: fixedStartPoint)
                
                path.line(to: topPoint)
                path.line(to: bottomPoint)
            }
        } else { // Vertical direction
            if dy > 0 { // Up direction
                let leftPoint = CGPoint(x: endPoint.x, y: endPoint.y)
                let rightPoint = CGPoint(x: endPoint.x + size.width, y: endPoint.y)

                let fixedStartPoint = startPoint
                path.move(to: fixedStartPoint)
        
                path.line(to: leftPoint)
                path.line(to: rightPoint)
            } else { // Down direction
                let leftPoint = CGPoint(x: endPoint.x, y: endPoint.y + size.height)
                let rightPoint = CGPoint(x: endPoint.x + size.width, y: endPoint.y + size.height)

                let fixedStartPoint = startPoint
                path.move(to: fixedStartPoint)
        
                path.line(to: leftPoint)
                path.line(to: rightPoint)
            }
        }

        path.close()
        return path
    }

}
