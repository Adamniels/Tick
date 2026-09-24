import AppKit

// Draws Tick's app icon at every macOS size into the asset catalog.
// Usage: swift scripts/make-app-icon.swift Tick/Assets.xcassets/AppIcon.appiconset
let out = CommandLine.arguments[1]

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 1024, height: 1024)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    // macOS icon grid: an 824 pt body centered on a 1024 canvas.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 24
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(srgbRed: 1.00, green: 0.55, blue: 0.25, alpha: 1),
        NSColor(srgbRed: 0.90, green: 0.22, blue: 0.20, alpha: 1),
    ])!.draw(in: shape, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: 470, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    let symbol = NSImage(systemSymbolName: "stopwatch", accessibilityDescription: nil)!.withSymbolConfiguration(config)!
    let size = symbol.size
    symbol.draw(in: NSRect(x: 512 - size.width / 2, y: 500 - size.height / 2, width: size.width, height: size.height))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)@\(scale)x.png"
        try! render(pixels: points * scale).write(to: URL(fileURLWithPath: "\(out)/\(name)"))
        images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)", "filename": name])
    }
}
let json: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let data = try! JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
try! data.write(to: URL(fileURLWithPath: "\(out)/Contents.json"))
print("wrote \(images.count) images")
