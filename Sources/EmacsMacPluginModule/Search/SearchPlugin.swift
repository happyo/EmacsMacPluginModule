//
//  Created by belyenochi on 2024/06/11.
//
import AppKit
import EmacsSwiftModule

class SearchPlugin: BasePlugin {
    var searchField: NSSearchField? = nil

    public override func initFunctions(_ env: Environment) throws {
        try genTestFunc(env)
    }

    private func genTestFunc(_ env: Environment) throws {
        try env.defun("swift-search-add-bar") { (env: Environment) in
            guard let window = NSApp.mainWindow, let screen = NSScreen.main else {
                try env.funcall("message", with: "No main window found")
                return
            }

            let x = 100
            let y = 100
    
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

            let searchField = NSSearchField(frame: NSRect(x: 300, y: 200, width: 200, height: 30))
            searchField.placeholderString = "Search"
            searchField.delegate = self
            window.contentView?.addSubview(searchField)
            self.searchField = searchField
        }
    }
}

extension SearchPlugin: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let searchField = searchField else { return }
        print(searchField.stringValue)
    }
}
