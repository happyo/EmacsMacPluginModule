//
//  Created by belyenochi on 2024/06/10.
//

import AppKit

class FrameHelper {
    static func relativePoint(from emacsPoint: NSPoint, window: NSWindow, screen: NSScreen) -> NSPoint {
            let windowFrame = window.frame
            let contentFrame = window.contentRect(forFrameRect: windowFrame)
            let screenHeight = screen.frame.height

            // transform to screen coordinates
            let transformedX = emacsPoint.x
            let transformedY = screenHeight - emacsPoint.y

            // transform to conent relative coordinates
            let relativeX = transformedX - contentFrame.origin.x
            let relativeY = transformedY - contentFrame.origin.y
            
        return NSPoint(x: relativeX, y: relativeY)
    }
}
