// Renders the 🔥 emoji on a crema squircle into AppIcon.icns: swift scripts/render-icon.swift
import AppKit

let emoji = "🔥"
let cremaCentre: UInt32 = 0xF8DDB8
let cremaEdge: UInt32 = 0xD0874A

func colour(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

func drawIcon(pixels: CGFloat) {
    let body = CGRect(x: 0, y: 0, width: pixels, height: pixels).insetBy(dx: pixels * 100 / 1024, dy: pixels * 100 / 1024)
    let squircle = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)

    NSGraphicsContext.saveGraphicsState()
    let dropShadow = NSShadow()
    dropShadow.shadowColor = colour(0x000000, 0.3)
    dropShadow.shadowOffset = NSSize(width: 0, height: -pixels * 0.01)
    dropShadow.shadowBlurRadius = pixels * 0.02
    dropShadow.set()
    colour(cremaEdge).setFill()
    squircle.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()
    NSGradient(starting: colour(cremaCentre), ending: colour(cremaEdge))!.draw(in: squircle, relativeCenterPosition: .zero)
    colour(0xffffff, 0.3).setStroke()
    squircle.lineWidth = body.width * 0.02
    squircle.stroke()

    let emojiShadow = NSShadow()
    emojiShadow.shadowColor = colour(0x3b2412, 0.35)
    emojiShadow.shadowOffset = NSSize(width: 0, height: -body.width * 0.02)
    emojiShadow.shadowBlurRadius = body.width * 0.04
    emojiShadow.set()
    let glyph = NSAttributedString(string: emoji, attributes: [.font: NSFont.systemFont(ofSize: body.width * 0.62)])
    let size = glyph.size()
    glyph.draw(at: NSPoint(x: body.midX - size.width / 2, y: body.midY - size.height / 2 - body.width * 0.01))
    NSGraphicsContext.restoreGraphicsState()
}

let iconset = URL(fileURLWithPath: "AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        drawIcon(pixels: CGFloat(pixels))
        NSGraphicsContext.restoreGraphicsState()
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
try FileManager.default.removeItem(at: iconset)
