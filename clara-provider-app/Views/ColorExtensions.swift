import SwiftUI

// MARK: - Color Extension
// Match patient app color branding
extension Color {
    static let primaryCoral = Color(red: 1.0, green: 0.35, blue: 0.2) // #FF5A33
    static let flaggedTeal = Color(red: 0.31, green: 0.8, blue: 0.77) // #4ECDC4
    static let paperBackground = Color(red: 0.949, green: 0.929, blue: 0.878) // Darker beige - #F2EDE0
    static let userBubbleBackground = Color(red: 0.937, green: 0.906, blue: 0.824) // #EFE7D2
    
    // Conditional colors that use paper colors in light mode, system colors in dark mode
    static func adaptiveBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(.systemBackground) : paperBackground // Beige base layer
    }
    
    static func adaptiveSecondaryBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color(red: 0.965, green: 0.945, blue: 0.885) // Slightly lighter than background (for cards/filters)
    }
    
    static func adaptiveTertiaryBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(red: 0.95, green: 0.93, blue: 0.87) // More visible layer
    }
    
    static func adaptiveLabel(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(.label) : Color(red: 0.2, green: 0.2, blue: 0.2) // Dark text for light mode
    }
    
    static func adaptiveSecondaryLabel(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(.secondaryLabel) : Color(red: 0.4, green: 0.4, blue: 0.4) // Medium gray for light mode
    }
}

extension UIColor {
    static let primaryCoral = UIColor(red: 1.0, green: 0.35, blue: 0.2, alpha: 1.0) // #FF5A33
}
