import AppKit
import SwiftUI

/// Colors are stored as "#RRGGBB" strings in sRGB, so they sync as plain text.
nonisolated enum HexColor {
    static let fallback = "#8E8E93"

    /// Parses "#RRGGBB" or "RRGGBB" (case-insensitive) into sRGB components in 0...1.
    static func components(from hex: String) -> (red: Double, green: Double, blue: Double)? {
        var digits = hex.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16) else {
            return nil
        }
        return (
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    static func string(red: Double, green: Double, blue: Double) -> String {
        func byte(_ component: Double) -> Int { Int((min(max(component, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}

extension Color {
    /// Invalid hex strings fall back to `HexColor.fallback`.
    init(hex: String) {
        let c = HexColor.components(from: hex) ?? HexColor.components(from: HexColor.fallback)!
        self.init(.sRGB, red: c.red, green: c.green, blue: c.blue)
    }

    /// The color converted to sRGB as "#RRGGBB". Out-of-gamut colors are clamped.
    var hexString: String {
        guard let srgb = NSColor(self).usingColorSpace(.sRGB) else { return HexColor.fallback }
        return HexColor.string(red: srgb.redComponent, green: srgb.greenComponent, blue: srgb.blueComponent)
    }
}

extension NSImage {
    /// A filled circle that keeps its color in menus and the menu bar, where
    /// SwiftUI shapes and SF Symbols are rendered as monochrome templates.
    static func dot(hex: String, diameter: CGFloat = 9) -> NSImage {
        let color = NSColor(Color(hex: hex))
        let image = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
