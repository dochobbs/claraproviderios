import SwiftUI
import os.log

// MARK: - Font Extension
extension Font {
    static func rethinkSans(_ size: CGFloat, relativeTo textStyle: TextStyle = .body) -> Font {
        // Try custom font first, fall back to system font if not available
        let uiFont = UIFont(name: "RethinkSans-Regular", size: size)
        if uiFont != nil {
            os_log("[FontExtensions] RethinkSans-Regular loaded successfully", log: .default, type: .debug)
            return .custom("RethinkSans-Regular", size: size, relativeTo: textStyle)
        } else {
            // Log warning if font not found - suggests bundle loading issue
            os_log("[FontExtensions] WARNING: RethinkSans-Regular not found, falling back to system font", log: .default, type: .error)
            // Fallback to system font with similar characteristics
            return .system(textStyle, design: .rounded)
        }
    }

    static func rethinkSansBold(_ size: CGFloat, relativeTo textStyle: TextStyle = .body) -> Font {
        // Try custom font first, fall back to system font if not available
        let uiFont = UIFont(name: "RethinkSans-Bold", size: size)
        if uiFont != nil {
            os_log("[FontExtensions] RethinkSans-Bold loaded successfully", log: .default, type: .debug)
            return .custom("RethinkSans-Bold", size: size, relativeTo: textStyle)
        } else {
            // Log warning if font not found - suggests bundle loading issue
            os_log("[FontExtensions] WARNING: RethinkSans-Bold not found, falling back to system font", log: .default, type: .error)
            // Fallback to system bold font with similar characteristics
            return .system(textStyle, design: .rounded).bold()
        }
    }
}

// MARK: - Font Verification Helper
extension Font {
    /// Debug helper to verify which fonts are available in the bundle
    static func debugListAvailableFonts() {
        let rethinkFonts = [
            "RethinkSans-Regular",
            "RethinkSans-Bold",
            "RethinkSans-Italic",
            "RethinkSans-BoldItalic",
            "RethinkSans-Medium",
            "RethinkSans-MediumItalic",
            "RethinkSans-SemiBold",
            "RethinkSans-SemiBoldItalic",
            "RethinkSans-ExtraBold",
            "RethinkSans-ExtraBoldItalic"
        ]

        os_log("[FontExtensions] Checking available fonts:", log: .default, type: .debug)
        for fontName in rethinkFonts {
            let available = UIFont(name: fontName, size: 16) != nil
            os_log("[FontExtensions] %{public}s: %{public}s", log: .default, type: .debug, fontName, available ? "✅ AVAILABLE" : "❌ NOT FOUND")
        }
    }
}

