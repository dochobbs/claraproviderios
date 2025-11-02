import SwiftUI

// MARK: - Font Extension
extension Font {
    static func rethinkSans(_ size: CGFloat, relativeTo textStyle: TextStyle = .body) -> Font {
        // Try custom font first, fall back to system font if not available
        if UIFont(name: "RethinkSans-Regular", size: size) != nil {
            return .custom("RethinkSans-Regular", size: size, relativeTo: textStyle)
        } else {
            // Fallback to system font with similar characteristics
            return .system(textStyle, design: .rounded)
        }
    }
    
    static func rethinkSansBold(_ size: CGFloat, relativeTo textStyle: TextStyle = .body) -> Font {
        // Try custom font first, fall back to system font if not available
        if UIFont(name: "RethinkSans-Bold", size: size) != nil {
            return .custom("RethinkSans-Bold", size: size, relativeTo: textStyle)
        } else {
            // Fallback to system bold font with similar characteristics
            return .system(textStyle, design: .rounded).bold()
        }
    }
}

