// Renders the app icon into an .iconset folder: swift Scripts/generate-icon.swift <output.iconset>
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func withGlow(_ glowColor: NSColor, radius: CGFloat, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = glowColor
    glow.shadowBlurRadius = radius
    glow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

func polar(_ center: NSPoint, _ radius: CGFloat, _ degrees: CGFloat) -> NSPoint {
    let angle = degrees * .pi / 180
    return NSPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
}

let blue = color(0x4DA6FF)
let orange = color(0xFF9F0A)
let red = color(0xFF4D4F)
let terracotta = color(0xD97757)

/// Draws on a 1024-point canvas following the macOS icon grid (824-point body, 100-point margin).
func drawIcon() {
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    color(0x1A1D2E).setFill()
    squircle.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()
    NSGradient(colors: [color(0x2A2F45), color(0x1A1D2E), color(0x0F111C)])!.draw(in: body, angle: -90)
    NSGradient(colors: [.white.withAlphaComponent(0.08), .white.withAlphaComponent(0)])!
        .draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    let hub = NSPoint(x: body.midX, y: 405)
    drawDial(center: hub, radius: 310, width: 64)
    drawNeedle(from: hub, length: 255, fraction: 0.66)
    drawSpark(center: hub, radius: 150)
}

/// A half-circle dial: blue up to 75%, orange to 100%, then a red limit zone.
func drawDial(center: NSPoint, radius: CGFloat, width: CGFloat) {
    let zones: [(from: CGFloat, to: CGFloat, color: NSColor)] = [
        (180, 50, blue),
        (48, 12, orange),
        (10, 0, red),
    ]
    for zone in zones {
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius, startAngle: zone.from, endAngle: zone.to, clockwise: true)
        path.lineWidth = width
        withGlow(zone.color.withAlphaComponent(0.5), radius: 20) {
            zone.color.setStroke()
            path.stroke()
        }
    }
    for step in 0...10 {
        let degrees = 180 - CGFloat(step) * 18
        let tick = NSBezierPath()
        tick.move(to: polar(center, radius - 70, degrees))
        tick.line(to: polar(center, radius - 50, degrees))
        tick.lineWidth = 10
        tick.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.5).setStroke()
        tick.stroke()
    }
}

func drawNeedle(from center: NSPoint, length: CGFloat, fraction: CGFloat) {
    let needle = NSBezierPath()
    needle.move(to: center)
    needle.line(to: polar(center, length, 180 - 180 * fraction))
    needle.lineWidth = 22
    needle.lineCapStyle = .round
    withGlow(.black.withAlphaComponent(0.5), radius: 12) {
        NSColor.white.setStroke()
        needle.stroke()
    }
}

/// Claude's symbol from `claude-symbol.svg` (100×100 view box), centered on `center`.
func drawSpark(center: NSPoint, radius: CGFloat) {
    let scale = radius * 2 / 100
    let symbol = svgPath(symbolPathData) { x, y in
        NSPoint(x: center.x + (x - 50) * scale, y: center.y - (y - 50) * scale)
    }
    withGlow(.black.withAlphaComponent(0.45), radius: 16) {
        terracotta.setFill()
        symbol.fill()
    }
}

let symbolPathData: String = {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "claude-symbol.svg")
    let svg = try! String(contentsOf: url, encoding: .utf8)
    let match = svg.firstMatch(of: try! Regex(#"\sd="([^"]+)""#))!
    return String(match.output[1].substring!)
}()

/// Parses the SVG path commands the symbol uses (M, L, H, V, C, Z, absolute and relative).
func svgPath(_ data: String, transform: (CGFloat, CGFloat) -> NSPoint) -> NSBezierPath {
    let tokens = data.matches(of: try! Regex(#"[MmLlHhVvCcZz]|-?(?:\d+\.?\d*|\.\d+)"#)).map { String(data[$0.range]) }
    let path = NSBezierPath()
    var index = 0
    var command = ""
    var current = CGPoint.zero
    var start = CGPoint.zero

    func number() -> CGFloat {
        defer { index += 1 }
        return CGFloat(Double(tokens[index])!)
    }
    func point(relative: Bool) -> CGPoint {
        let x = number(), y = number()
        return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
    }

    while index < tokens.count {
        if tokens[index].first!.isLetter {
            command = tokens[index]
            index += 1
        }
        let relative = command == command.lowercased()
        switch command.uppercased() {
        case "M":
            current = point(relative: relative)
            start = current
            path.move(to: transform(current.x, current.y))
            command = relative ? "l" : "L"
        case "L":
            current = point(relative: relative)
            path.line(to: transform(current.x, current.y))
        case "H":
            let x = number()
            current.x = relative ? current.x + x : x
            path.line(to: transform(current.x, current.y))
        case "V":
            let y = number()
            current.y = relative ? current.y + y : y
            path.line(to: transform(current.x, current.y))
        case "C":
            let origin = current
            func control() -> CGPoint {
                let x = number(), y = number()
                return relative ? CGPoint(x: origin.x + x, y: origin.y + y) : CGPoint(x: x, y: y)
            }
            let first = control(), second = control(), end = control()
            current = end
            path.curve(
                to: transform(end.x, end.y),
                controlPoint1: transform(first.x, first.y),
                controlPoint2: transform(second.x, second.y)
            )
        case "Z":
            path.close()
            current = start
        default:
            fatalError("Unsupported SVG path command \(command)")
        }
    }
    return path
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try render(pixels: size).write(to: output.appending(path: "icon_\(size)x\(size).png"))
    try render(pixels: size * 2).write(to: output.appending(path: "icon_\(size)x\(size)@2x.png"))
}
