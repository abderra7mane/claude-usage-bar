import AppKit
import ClaudeUsageCore

/// Draws every account shown in the menu bar into one image: per account, two stacked bars
/// (5-hour session on top, weekly below) followed by the optional name and percentages.
enum StatusIcon {
    struct Entry {
        let name: String?
        let session: UsageWindow?
        let weekly: UsageWindow?
        let percentages: String?
        let dimmed: Bool
    }

    private static let height: CGFloat = 20
    private static let barSize = NSSize(width: 22, height: 5)
    private static let barGap: CGFloat = 3
    private static let plateInset = NSSize(width: 3, height: 3.5)
    private static let plateRadius: CGFloat = 4
    private static let plateAlpha: CGFloat = 0.08
    private static var plateWidth: CGFloat { barSize.width + plateInset.width * 2 }
    private static var plateHeight: CGFloat { barSize.height * 2 + barGap + plateInset.height * 2 }
    private static let textGap: CGFloat = 4
    private static let entryGap: CGFloat = 10
    private static let separatorSize = NSSize(width: 1, height: 12)
    private static let separatorAlpha: CGFloat = 0.25
    private static let dimmedAlpha: CGFloat = 0.45
    private static let updateGlyphScale: CGFloat = 0.55
    private static let updateGlyphCutout: CGFloat = 1.5
    private static var updateGlyphSize: NSSize { NSSize(width: 15 * updateGlyphScale, height: 20 * updateGlyphScale) }
    private static var font: NSFont {
        .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .medium)
    }

    /// Text and the plate behind the bars use dynamic colors, which resolve when the image is drawn,
    /// so they follow the menu bar's appearance. When an update is available, a download arrow is drawn over
    /// the last plate's bottom-right corner.
    static func image(entries: [Entry], updateAvailable: Bool, now: Date) -> NSImage {
        let entries = entries.isEmpty ? [Entry(name: nil, session: nil, weekly: nil, percentages: nil, dimmed: false)] : entries
        let texts = entries.map { text(for: $0) }
        let widths = zip(entries, texts).map { _, text in
            plateWidth + (text.map { textGap + ceil($0.size().width) } ?? 0)
        }
        let size = NSSize(width: widths.reduce(0, +) + entryGap * CGFloat(entries.count - 1), height: height)

        let image = NSImage(size: size, flipped: true) { rect in
            var x: CGFloat = 0
            var lastPlateX: CGFloat = 0
            for (index, entry) in entries.enumerated() {
                lastPlateX = x
                let context = NSGraphicsContext.current?.cgContext
                if entry.dimmed {
                    context?.saveGState()
                    context?.setAlpha(dimmedAlpha)
                    context?.beginTransparencyLayer(auxiliaryInfo: nil)
                }
                draw(entry, text: texts[index], at: x, height: rect.height, now: now)
                if entry.dimmed {
                    context?.endTransparencyLayer()
                    context?.restoreGState()
                }
                x += widths[index] + entryGap
                if index < entries.count - 1 {
                    drawSeparator(at: x - entryGap / 2, height: rect.height)
                }
            }
            if updateAvailable {
                drawUpdateGlyph(over: plateRect(at: lastPlateX, height: rect.height))
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func text(for entry: Entry) -> NSAttributedString? {
        let parts = [entry.name, entry.percentages].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return NSAttributedString(
            string: parts.joined(separator: " "),
            attributes: [.font: font, .foregroundColor: NSColor.labelColor]
        )
    }

    private static func draw(_ entry: Entry, text: NSAttributedString?, at x: CGFloat, height: CGFloat, now: Date) {
        let plate = plateRect(at: x, height: height)
        NSColor.textBackgroundColor.withAlphaComponent(plateAlpha).setFill()
        NSBezierPath(roundedRect: plate, xRadius: plateRadius, yRadius: plateRadius).fill()

        let top = NSRect(
            origin: NSPoint(x: plate.minX + plateInset.width, y: plate.minY + plateInset.height),
            size: barSize
        )
        drawBar(in: top, window: entry.session, now: now)
        drawBar(in: top.offsetBy(dx: 0, dy: barSize.height + barGap), window: entry.weekly, now: now)

        if let text {
            let textSize = text.size()
            text.draw(at: NSPoint(x: x + plateWidth + textGap, y: (height - textSize.height) / 2))
        }
    }

    private static func plateRect(at x: CGFloat, height: CGFloat) -> NSRect {
        NSRect(x: x, y: (height - plateHeight) / 2, width: plateWidth, height: plateHeight)
    }

    private static func drawSeparator(at x: CGFloat, height: CGFloat) {
        let line = NSRect(
            origin: NSPoint(x: x - separatorSize.width / 2, y: (height - separatorSize.height) / 2),
            size: separatorSize
        )
        NSColor.labelColor.withAlphaComponent(separatorAlpha).setFill()
        line.fill()
    }

    /// Clears a gap around the arrow so it stands out from the bars beneath it.
    private static func drawUpdateGlyph(over plate: NSRect) {
        let path = updateGlyphPath(origin: NSPoint(
            x: plate.maxX - updateGlyphSize.width,
            y: plate.maxY - updateGlyphSize.height
        ))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .clear
        path.lineWidth = updateGlyphCutout * 2
        path.lineJoinStyle = .round
        path.stroke()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.labelColor.setFill()
        path.fill()
    }

    /// The arrow from BetterDisplay's update icon, in a 15×20 unit space.
    private static func updateGlyphPath(origin: NSPoint) -> NSBezierPath {
        func p(_ px: CGFloat, _ py: CGFloat) -> NSPoint {
            NSPoint(x: origin.x + px * updateGlyphScale, y: origin.y + py * updateGlyphScale)
        }
        let path = NSBezierPath()
        path.move(to: p(7.4939, 15.3667))
        path.curve(to: p(8.7998, 14.8002), controlPoint1: p(8.0095, 15.3667), controlPoint2: p(8.4771, 15.1237))
        path.line(to: p(14.1154, 9.2632))
        path.curve(to: p(14.6699, 7.9196), controlPoint1: p(14.4994, 8.8919), controlPoint2: p(14.6699, 8.3812))
        path.curve(to: p(13.0015, 6.0065), controlPoint1: p(14.6699, 6.7881), controlPoint2: p(13.949, 6.0065))
        path.curve(to: p(11.713, 6.642), controlPoint1: p(12.4503, 6.0065), controlPoint2: p(12.0448, 6.2796))
        path.line(to: p(10.6191, 7.8263))
        path.line(to: p(9.0499, 9.8166))
        path.line(to: p(9.2674, 7.3365))
        path.line(to: p(9.2674, 2.038))
        path.curve(to: p(7.4939, 0), controlPoint1: p(9.2674, 0.835), controlPoint2: p(8.5557, 0))
        path.curve(to: p(5.7203, 2.038), controlPoint1: p(6.4279, 0), controlPoint2: p(5.7203, 0.835))
        path.line(to: p(5.7203, 7.3365))
        path.line(to: p(5.9379, 9.8211))
        path.line(to: p(4.3563, 7.8219))
        path.line(to: p(3.2871, 6.642))
        path.curve(to: p(2.0158, 6.0065), controlPoint1: p(2.9552, 6.2651), controlPoint2: p(2.5753, 6.0065))
        path.curve(to: p(0.3433, 7.9196), controlPoint1: p(1.0469, 6.0065), controlPoint2: p(0.3433, 6.7791))
        path.curve(to: p(0.8896, 9.2586), controlPoint1: p(0.3433, 8.3678), controlPoint2: p(0.5354, 8.8818))
        path.line(to: p(6.1879, 14.8002))
        path.curve(to: p(7.4939, 15.3667), controlPoint1: p(6.5106, 15.1426), controlPoint2: p(6.9823, 15.3667))
        path.close()
        path.move(to: p(1.703, 20))
        path.line(to: p(13.3102, 20))
        path.curve(to: p(15, 18.1503), controlPoint1: p(14.2526, 20), controlPoint2: p(15, 19.1794))
        path.curve(to: p(13.3102, 16.3051), controlPoint1: p(15, 17.1257), controlPoint2: p(14.2526, 16.3051))
        path.line(to: p(1.703, 16.3051))
        path.curve(to: p(0, 18.1503), controlPoint1: p(0.7606, 16.3051), controlPoint2: p(0, 17.1257))
        path.curve(to: p(1.703, 20), controlPoint1: p(0, 19.1794), controlPoint2: p(0.7606, 20))
        path.close()
        return path
    }

    private static func drawBar(in rect: NSRect, window: UsageWindow?, now: Date) {
        let radius = rect.height / 2
        guard let window else {
            NSColor.gray.withAlphaComponent(0.45).setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return
        }

        let color = window.level(at: now).nsColor
        color.withAlphaComponent(0.3).setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

        let fraction = min(max(window.effectiveUtilization(at: now) / 100, 0), 1)
        guard fraction > 0 else { return }
        var fill = rect
        fill.size.width = max(rect.width * fraction, rect.height)
        color.setFill()
        NSBezierPath(roundedRect: fill, xRadius: radius, yRadius: radius).fill()
    }
}
