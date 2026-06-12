//
//  Created by belyenochi on 2024/06/11.
//

import AppKit
import EmacsSwiftModule

/// Kitty-style "jelly" cursor trail, ported from kitty's cursor_trail.c.
///
/// A translucent quad whose four corners independently chase the four
/// corners of the real cursor. Corners aligned with the movement
/// direction (measured with a dot product against the cursor center)
/// use the fast decay and arrive first, trailing corners use the slow
/// decay, which stretches the quad into a jelly-like streak that
/// snaps back onto the cursor with an exponential ease-out.
class CursorPlugin: BasePlugin {
    // MARK: - Configuration

    private var cursorColor: NSColor = .red
    private var shadowOpacity: Double = 0.8
    /// Seconds for the leading corners to cover ~99.9% of their distance.
    /// (kitty: cursor_trail_decay first value)
    private var trailDecayFast: Double = 0.1
    /// Seconds for the trailing corners to cover ~99.9% of their distance.
    /// (kitty: cursor_trail_decay second value)
    private var trailDecaySlow: Double = 0.4
    /// Minimum cursor movement (Manhattan distance in cells) that triggers
    /// the trail. 0 disables the threshold. (kitty: cursor_trail_start_threshold)
    private var trailStartThreshold: Int = 2

    // MARK: - Trail state (mirrors kitty's CursorTrail struct)

    /// Trail corners, ordered (right,top), (right,bottom), (left,bottom), (left,top),
    /// matching kitty's corner_index = {{1,1,0,0},{0,1,1,0}}.
    private var corners = [CGPoint](repeating: .zero, count: 4)
    /// Cursor rect in contentView coordinates (AppKit, origin bottom-left).
    private var targetRect: CGRect = .zero
    private var cellSize = CGSize(width: 1, height: 1)
    private var trailOpacity: Double = 0
    private var needsRender = false
    private var hasTarget = false
    private var updatedAt: CFTimeInterval = CACurrentMediaTime()

    private var trailLayer: CAShapeLayer? = nil
    private weak var hostView: NSView? = nil
    private var displayTimer: Timer? = nil

    deinit {
        displayTimer?.invalidate()
        trailLayer?.removeFromSuperlayer()
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
            self.stopDisplayTimer()
            self.trailLayer?.removeFromSuperlayer()
            self.trailLayer = nil
            self.hostView = nil
            self.hasTarget = false
            self.needsRender = false
        }

        try env.defun("swift-set-cursor-color") { (env: Environment, colorString: String) in
            if let color = NSColor(hexString: colorString) {
                self.cursorColor = color
                self.trailLayer?.fillColor = color.cgColor
            }
        }

        try env.defun("swift-set-shadow-opacity") { (env: Environment, opacity: Double) in
            self.shadowOpacity = opacity
        }

        try env.defun(
            "swift-set-trail-decay",
            with: "Set cursor trail decay seconds: FAST for leading corners, SLOW for trailing corners."
        ) { (env: Environment, fast: Double, slow: Double) in
            self.trailDecayFast = max(0.01, fast)
            self.trailDecaySlow = max(self.trailDecayFast, slow)
        }

        try env.defun(
            "swift-set-trail-threshold",
            with: "Set minimum cursor movement in cells required to start the trail. 0 disables the threshold."
        ) { (env: Environment, cells: Int) in
            self.trailStartThreshold = max(0, cells)
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
            guard let window = NSApp.mainWindow, let screen = NSScreen.main,
                  let contentView = window.contentView else {
                try env.funcall("message", with: "No main window found")
                return
            }

            let relativePoint = FrameHelper.relativePoint(from: NSPoint(x: model.x, y: model.y), window: window, screen: screen)

            // relativePoint is the top edge of the glyph; AppKit rects grow upwards.
            let rect = CGRect(
                x: relativePoint.x,
                y: relativePoint.y - CGFloat(model.height),
                width: CGFloat(max(model.width, 1)),
                height: CGFloat(max(model.height, 1))
            )

            self.cellSize = CGSize(width: rect.width, height: rect.height)
            self.updateCursorTarget(rect: rect, in: contentView)
        }
    }

    // MARK: - Target updates (kitty: update_cursor_trail_target)

    /// Target positions for the four trail corners, ordered like kitty's
    /// corner_index: (right,top), (right,bottom), (left,bottom), (left,top).
    private var cornerTargets: [CGPoint] {
        [
            CGPoint(x: targetRect.maxX, y: targetRect.maxY),
            CGPoint(x: targetRect.maxX, y: targetRect.minY),
            CGPoint(x: targetRect.minX, y: targetRect.minY),
            CGPoint(x: targetRect.minX, y: targetRect.maxY),
        ]
    }

    private func updateCursorTarget(rect: CGRect, in view: NSView) {
        ensureTrailLayer(in: view)

        targetRect = rect

        // First target after (re)attach: snap without animating.
        if !hasTarget {
            hasTarget = true
            snapCornersToTarget()
            return
        }

        if shouldSkipTrailUpdate() {
            snapCornersToTarget()
            return
        }

        startDisplayTimerIfNeeded()
    }

    /// kitty: should_skip_cursor_trail_update
    private func shouldSkipTrailUpdate() -> Bool {
        if hostView?.window?.inLiveResize == true {
            return true
        }
        if trailStartThreshold > 0 && !needsRender {
            let targets = cornerTargets
            let dx = lround((corners[0].x - targets[0].x) / cellSize.width)
            let dy = lround((corners[0].y - targets[0].y) / cellSize.height)
            if abs(dx) + abs(dy) <= trailStartThreshold {
                return true
            }
        }
        return false
    }

    private func snapCornersToTarget() {
        corners = cornerTargets
        needsRender = false
        stopDisplayTimer()
        trailLayer?.isHidden = true
        redrawTrail()
    }

    // MARK: - Per-frame animation

    private func startDisplayTimerIfNeeded() {
        trailLayer?.isHidden = false
        guard displayTimer == nil else { return }
        updatedAt = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    /// kitty: update_cursor_trail
    private func tick() {
        let now = CACurrentMediaTime()
        let dt = max(0, now - updatedAt)
        updatedAt = now

        updateCorners(dt: dt)
        updateOpacity(dt: dt)

        let needsRenderPrev = needsRender
        updateNeedsRender()
        redrawTrail()

        // Keep drawing one extra frame after convergence (kitty returns
        // needs_render || needs_render_prev), then hide and stop.
        if !needsRender && !needsRenderPrev {
            stopDisplayTimer()
            trailLayer?.isHidden = true
        }
    }

    /// kitty: update_cursor_trail_corners
    ///
    /// Each corner moves towards its cursor corner at a speed proportional
    /// to the remaining distance (exponential ease-out). The dot product of
    /// the movement direction and the cursor-center-to-corner vector decides
    /// how fast each corner is: leading corners decay fast, trailing slow.
    private func updateCorners(dt: CFTimeInterval) {
        let targets = cornerTargets
        let centerX = targetRect.midX
        let centerY = targetRect.midY
        let halfDiag = hypot(targetRect.width, targetRect.height) * 0.5
        guard halfDiag > 0, dt > 0 else { return }

        var dx = [CGFloat](repeating: 0, count: 4)
        var dy = [CGFloat](repeating: 0, count: 4)
        var dot = [CGFloat](repeating: 0, count: 4)
        var minDot = CGFloat.greatestFiniteMagnitude
        var maxDot = -CGFloat.greatestFiniteMagnitude

        for i in 0..<4 {
            dx[i] = targets[i].x - corners[i].x
            dy[i] = targets[i].y - corners[i].y
            if abs(dx[i]) < 1e-6 && abs(dy[i]) < 1e-6 {
                dx[i] = 0
                dy[i] = 0
                dot[i] = 0
            } else {
                dot[i] = (dx[i] * (targets[i].x - centerX) + dy[i] * (targets[i].y - centerY))
                    / halfDiag / hypot(dx[i], dy[i])
            }
            minDot = min(minDot, dot[i])
            maxDot = max(maxDot, dot[i])
        }

        for i in 0..<4 {
            if dx[i] == 0 && dy[i] == 0 { continue }

            let decay = (maxDot - minDot) < 1e-6
                ? trailDecaySlow
                : trailDecaySlow + (trailDecayFast - trailDecaySlow) * Double((dot[i] - minDot) / (maxDot - minDot))
            let step = CGFloat(1.0 - exp2(-10.0 * dt / decay))
            corners[i].x += dx[i] * step
            corners[i].y += dy[i] * step
        }
    }

    /// kitty: update_cursor_trail_opacity (Emacs cursor is always visible,
    /// so only the fade-in branch is needed).
    private func updateOpacity(dt: CFTimeInterval) {
        trailOpacity = min(trailOpacity + dt / trailDecaySlow, 1.0)
    }

    /// kitty: update_cursor_trail_needs_render — keep rendering while any
    /// corner is more than half a pixel away from its cursor corner.
    private func updateNeedsRender() {
        needsRender = false
        let targets = cornerTargets
        for i in 0..<4 {
            if abs(targets[i].x - corners[i].x) >= 0.5 || abs(targets[i].y - corners[i].y) >= 0.5 {
                needsRender = true
                return
            }
        }
    }

    // MARK: - Rendering

    private func ensureTrailLayer(in view: NSView) {
        if let layer = trailLayer, hostView === view, layer.superlayer === view.layer {
            return
        }
        trailLayer?.removeFromSuperlayer()
        view.wantsLayer = true

        let layer = CAShapeLayer()
        layer.zPosition = 1000
        layer.fillColor = cursorColor.cgColor
        layer.isHidden = true
        view.layer?.addSublayer(layer)

        trailLayer = layer
        hostView = view
        // Snap on the next target so the trail doesn't fly across windows.
        hasTarget = false
    }

    private func redrawTrail() {
        guard let layer = trailLayer else { return }

        let path = CGMutablePath()
        path.move(to: corners[0])
        path.addLine(to: corners[1])
        path.addLine(to: corners[2])
        path.addLine(to: corners[3])
        path.closeSubpath()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.path = path
        layer.fillColor = cursorColor.cgColor
        layer.opacity = Float(trailOpacity * shadowOpacity)
        CATransaction.commit()
    }
}
