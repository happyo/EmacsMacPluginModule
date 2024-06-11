//
//  Created by belyenochi on 2024/06/09.
//
import AppKit
import EmacsSwiftModule

class NSWindowInfoModel: OpaquelyEmacsConvertible {
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
