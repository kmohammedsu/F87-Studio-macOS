import AppKit

let destination = CommandLine.arguments[1]
let size = 1024
guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                    isPlanar: false, colorSpaceName: .deviceRGB,
                                    bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let canvas = NSRect(x: 0, y: 0, width: size, height: size)
NSColor.clear.setFill()
canvas.fill()

let outer = NSBezierPath(roundedRect: NSRect(x: 36, y: 36, width: 952, height: 952), xRadius: 224, yRadius: 224)
NSGradient(colors: [NSColor(calibratedWhite: 0.18, alpha: 1),
                    NSColor(calibratedWhite: 0.055, alpha: 1)])!.draw(in: outer, angle: -70)

let innerHighlight = NSBezierPath(roundedRect: NSRect(x: 54, y: 54, width: 916, height: 916), xRadius: 207, yRadius: 207)
NSColor(calibratedWhite: 1, alpha: 0.08).setStroke()
innerHighlight.lineWidth = 3
innerHighlight.stroke()

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.50)
shadow.shadowBlurRadius = 32
shadow.shadowOffset = NSSize(width: 0, height: -18)
shadow.set()
let boardShadow = NSBezierPath(roundedRect: NSRect(x: 132, y: 264, width: 760, height: 500), xRadius: 72, yRadius: 72)
NSColor(calibratedWhite: 0.19, alpha: 1).setFill()
boardShadow.fill()
NSGraphicsContext.restoreGraphicsState()

let board = NSBezierPath(roundedRect: NSRect(x: 132, y: 264, width: 760, height: 500), xRadius: 72, yRadius: 72)
NSGradient(colors: [NSColor(calibratedWhite: 0.24, alpha: 1),
                    NSColor(calibratedWhite: 0.14, alpha: 1)])!.draw(in: board, angle: -90)
NSColor(calibratedWhite: 1, alpha: 0.16).setStroke()
board.lineWidth = 3
board.stroke()

func drawKey(_ rect: NSRect, accent: NSColor? = nil, label: String? = nil) {
    let radius = min(13, rect.height * 0.22)
    let key = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    (accent ?? NSColor(calibratedWhite: 0.075, alpha: 1)).setFill()
    key.fill()
    NSColor(calibratedWhite: 1, alpha: accent == nil ? 0.16 : 0.24).setStroke()
    key.lineWidth = 2
    key.stroke()
    if let label {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 34, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.88),
            .kern: 3
        ]
        let text = NSAttributedString(string: label, attributes: attributes)
        let textSize = text.size()
        text.draw(at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2))
    }
}

let startX: CGFloat = 184
let small: CGFloat = 48
let gap: CGFloat = 14
let accents = [
    NSColor(calibratedRed: 0.16, green: 0.48, blue: 0.96, alpha: 1),
    NSColor(calibratedRed: 0.35, green: 0.27, blue: 0.83, alpha: 1),
    NSColor(calibratedRed: 0.08, green: 0.63, blue: 0.56, alpha: 1)
]
for column in 0..<11 {
    let accentedColumns = [2, 6, 9]
    let accent = accentedColumns.firstIndex(of: column).map { accents[$0] }
    drawKey(NSRect(x: startX + CGFloat(column) * (small + gap), y: 654, width: small, height: 42), accent: accent)
}

for row in 0..<3 {
    let y = CGFloat(562 - row * 82)
    let inset = CGFloat(row) * 10
    for column in 0..<10 {
        drawKey(NSRect(x: startX + inset + CGFloat(column) * 62, y: y, width: 50, height: 58))
    }
}

drawKey(NSRect(x: 184, y: 316, width: 92, height: 58))
drawKey(NSRect(x: 290, y: 316, width: 58, height: 58))
drawKey(NSRect(x: 362, y: 316, width: 300, height: 58), label: "F87")
drawKey(NSRect(x: 676, y: 316, width: 58, height: 58))
drawKey(NSRect(x: 748, y: 316, width: 92, height: 58))

let strip = NSBezierPath(roundedRect: NSRect(x: 212, y: 285, width: 600, height: 8), xRadius: 4, yRadius: 4)
NSGradient(colors: [accents[0], accents[1], accents[2]])!.draw(in: strip, angle: 0)

NSColor(calibratedRed: 0.29, green: 0.78, blue: 0.47, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 817, y: 706, width: 18, height: 18)).fill()

NSGraphicsContext.restoreGraphicsState()
guard let data = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: URL(fileURLWithPath: destination), options: .atomic)
