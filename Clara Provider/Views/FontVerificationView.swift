import SwiftUI
import UIKit

/// Debug view to verify custom fonts are loaded
struct FontVerificationView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Font Verification")
                .font(.rethinkSansBold(24, relativeTo: .title))
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                FontTestRow(
                    name: "RethinkSans-Regular",
                    font: .rethinkSans(17, relativeTo: .body)
                )
                
                FontTestRow(
                    name: "RethinkSans-Bold",
                    font: .rethinkSansBold(17, relativeTo: .body)
                )
                
                FontTestRow(
                    name: "System Font (for comparison)",
                    font: .system(.body, design: .rounded)
                )
            }
            .padding()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Available Fonts:")
                    .font(.rethinkSansBold(17, relativeTo: .headline))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(availableFonts, id: \.self) { fontName in
                            Text(fontName)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            .padding()
        }
        .padding()
    }
    
    private var availableFonts: [String] {
        var fonts: [String] = []
        for family in UIFont.familyNames.sorted() {
            for name in UIFont.fontNames(forFamilyName: family).sorted() {
                if name.contains("Rethink") {
                    fonts.append(name)
                }
            }
        }
        return fonts.isEmpty ? ["No RethinkSans fonts found"] : fonts
    }
}

struct FontTestRow: View {
    let name: String
    let font: Font
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            Text("The quick brown fox jumps over the lazy dog")
                .font(font)
            Text("1234567890")
                .font(font)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    FontVerificationView()
}

