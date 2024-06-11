//
//  Created by belyenochi on 2024/06/11.
//
import AppKit
import EmacsSwiftModule

class SearchPlugin: BasePlugin {
    var searchField: NSSearchField? = nil
    var env: Environment? = nil
    let searchDirectory = "~/.emacs.d/" // 设置要搜索的目录路径
    var errorView: NSTextView? = nil
    
    public override func initFunctions(_ env: Environment) throws {
        self.env = env
        
        try genTestFunc(env)
    }

    private func genTestFunc(_ env: Environment) throws {
        try env.defun("swift-search-add-bar") { (env: Environment) in
            guard let window = NSApp.mainWindow, let screen = NSScreen.main else {
                try env.funcall("message", with: "No main window found")
                return
            }

            let searchField = NSSearchField(frame: NSRect(x: 300, y: 200, width: 200, height: 30))
            searchField.placeholderString = "Search"
            searchField.delegate = self
            window.contentView?.addSubview(searchField)
            self.searchField = searchField

            let errorView = NSTextView(frame: NSRect(x: 300, y: 100, width: 200, height: 30))
            errorView.string = "Error View"
            window.contentView?.addSubview(errorView)
            self.errorView = errorView
            
            // self.executeFdCommand(with: "mini")

        }
    }
    
private func executeFdCommand(with searchText: String) {
        let process = Process()
        process.launchPath = "/opt/homebrew/bin/fd" // 确认 fd 的路径
        process.arguments = [searchText]
        process.currentDirectoryPath = searchDirectory // 设置工作目录

        let pipe = Pipe()
        process.standardOutput = pipe

        let fileHandle = pipe.fileHandleForReading
        
        do {
            try process.run()
            process.waitUntilExit()

            let data = fileHandle.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            DispatchQueue.main.async {
                self.errorView?.string = output
            }
        } catch {
            print("Error executing fd command: \(error)")
        }
    }
}

extension SearchPlugin: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let searchField = searchField else { return }
        let searchText = searchField.stringValue
        executeFdCommand(with: searchText)
    }
}
