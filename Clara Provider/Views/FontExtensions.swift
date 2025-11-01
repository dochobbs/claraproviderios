import SwiftUI

// MARK: - Font Extension
extension Font {
    static func rethinkSans(_ size: CGFloat, relativeTo textStyle: TextStyle = .body) -> Font {
        .custom("RethinkSans-Regular", size: size, relativeTo: textStyle)
    }
    
    static func rethinkSansBold(_ size: CGFloat, relativeTo textStyle: TextStyle = .body) -> Font {
        .custom("RethinkSans-Bold", size: size, relativeTo: textStyle)
    }
}

