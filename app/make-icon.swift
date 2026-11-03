import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func rgb(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
}

let inset: CGFloat = 100
let body = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
rgb(0x0f1115).setFill()
NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185).fill()

let up = rgb(0xf04452), down = rgb(0x3182f6)
let candles: [(x: CGFloat, lo: CGFloat, open: CGFloat, close: CGFloat, hi: CGFloat, vol: CGFloat)] = [
    (270, 470, 520, 640, 700, 70),
    (420, 440, 620, 500, 680, 110),
    (570, 520, 540, 720, 790, 150),
    (720, 600, 700, 840, 880, 95),
]
for c in candles {
    let color = c.close >= c.open ? up : down
    color.setFill()
    NSRect(x: c.x - 9, y: c.lo, width: 18, height: c.hi - c.lo).fill()
    let top = max(c.open, c.close), bottom = min(c.open, c.close)
    NSBezierPath(roundedRect: NSRect(x: c.x - 46, y: bottom, width: 92, height: top - bottom), xRadius: 10, yRadius: 10).fill()
    color.withAlphaComponent(0.55).setFill()
    NSBezierPath(roundedRect: NSRect(x: c.x - 46, y: 200, width: 92, height: c.vol), xRadius: 8, yRadius: 8).fill()
}

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
