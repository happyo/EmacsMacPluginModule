//
//  Created by belyenochi on 2024/06/09.
//
import AppKit

extension NSColor {
    convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        
        guard hex.count == 6 || hex.count == 8 else {
            return nil
        }
        
        if hex.count == 6 {
            hex += "FF"
        }
        
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let r = CGFloat((int >> 24) & 0xFF) / 255.0
        let g = CGFloat((int >> 16) & 0xFF) / 255.0
        let b = CGFloat((int >> 8) & 0xFF) / 255.0
        let a = CGFloat(int & 0xFF) / 255.0
        
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
