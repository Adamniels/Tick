import SwiftUI

/// A small project or tag color swatch for use inside windows (menus need `NSImage.dot`).
struct ColorDot: View {
    let hex: String
    var diameter: CGFloat = 9

    var body: some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: diameter, height: diameter)
    }
}
