// The Swift Programming Language
// https://docs.swift.org/swift-book
import AppKit
import EmacsSwiftModule

class EmacsMacPluginModule: Module {
    let isGPLCompatible = true

    var env: Environment?
    var redView: NSView? = nil
    var animationTimer: Timer? = nil

    func Init(_ env: Environment) throws {
        try env.defun(
            "macos-module--update-window-info",
            with: """
            Update the window information.
            """
        ) { (env: Environment, x: Int, y: Int) in
            if let _ = self.redView {
                self.scheduleAnimation(toX: x, toY: y)

            } else {
                self.setupRedView(x: x, y: y)
            }

        }
    }

    private func setupRedView(x: Int, y: Int) {
        guard let view = NSApp.mainWindow?.contentView else { return }
        let redView = NSView(frame: NSRect(x: x, y: y, width: 10, height: 30))
        redView.wantsLayer = true
        redView.layer?.backgroundColor = NSColor.red.cgColor
        view.addSubview(redView)
        self.redView = redView
    }

    private func scheduleAnimation(toX x: Int, toY y: Int) {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            self.performAnimation(toX: x, toY: y)
        }
    }

    private func performAnimation(toX x: Int, toY y: Int) {
        guard let view = NSApp.mainWindow?.contentView, let redView = self.redView else { return }
        let realX = x
        let realY = Int(view.bounds.height) - y

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            redView.animator().setFrameOrigin(NSPoint(x: realX, y: realY))
        }, completionHandler: {
            // Handle completion if necessary
        })
    }
}

func createModule() -> Module { EmacsMacPluginModule() }

