import AppKit

let states: [(file: String, symbol: String, title: String)] = [
    ("clear", "flame", ""),
    ("attention", "flame.fill", " 3"),
    ("error", "flame", " !"),
]
let themes: [(suffix: String, colour: NSColor)] = [("light", .black), ("dark", .white)]
let scale: CGFloat = 2
let height: CGFloat = 22

for state in states {
    for theme in themes {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium, scale: .medium)
            .applying(.init(paletteColors: [theme.colour]))
        let symbol = NSImage(systemSymbolName: state.symbol, accessibilityDescription: nil)!.withSymbolConfiguration(config)!
        let text = NSAttributedString(string: state.title, attributes: [
            .font: NSFont.menuBarFont(ofSize: 0), .foregroundColor: theme.colour,
        ])
        let width = ceil(symbol.size.width + text.size().width) + 8
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        symbol.draw(in: NSRect(x: 4, y: (height - symbol.size.height) / 2, width: symbol.size.width, height: symbol.size.height))
        text.draw(at: NSPoint(x: 4 + symbol.size.width, y: (height - text.size().height) / 2))
        NSGraphicsContext.restoreGraphicsState()
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "docs/menubar/\(state.file)-\(theme.suffix).png"))
    }
}
