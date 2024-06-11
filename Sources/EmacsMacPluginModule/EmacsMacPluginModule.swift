// The Swift Programming Language
// https://docs.swift.org/swift-book
import AppKit
import EmacsSwiftModule

class EmacsMacPluginModule: Module {
    let isGPLCompatible = true

    var env: Environment?
    let cursorPlugin = CursorPlugin()
    let searchPlugin = SearchPlugin()

    func Init(_ env: Environment) throws {
        try cursorPlugin.initFunctions(env)
        try searchPlugin.initFunctions(env)
    }
}

func createModule() -> Module { EmacsMacPluginModule() }

