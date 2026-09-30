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

    private static let height: CGFloat = 16
    private static let barSize = NSSize(width: 22, height: 5)
    private static let barGap: CGFloat = 3
    private static let textGap: CGFloat = 4
    private static let entryGap: CGFloat = 10
    private static let dimmedAlpha: CGFloat = 0.45
    private static var font: NSFont {
        .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .medium)
    }

    /// Text uses `labelColor`, which resolves when the image is drawn, so it follows the menu bar's appearance.
    static func image(entries: [Entry], now: Date) -> NSImage {
        let entries = entries.isEmpty ? [Entry(name: nil, session: nil, weekly: nil, percentages: nil, dimmed: false)] : entries
        let texts = entries.map { text(for: $0) }
        let widths = zip(entries, texts).map { _, text in
            barSize.width + (text.map { textGap + ceil($0.size().width) } ?? 0)
        }
        let size = NSSize(width: widths.reduce(0, +) + entryGap * CGFloat(entries.count - 1), height: height)

        let image = NSImage(size: size, flipped: true) { rect in
            var x: CGFloat = 0
            for (index, entry) in entries.enumerated() {
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
        let top = NSRect(
            origin: NSPoint(x: x, y: (height - barSize.height * 2 - barGap) / 2),
            size: barSize
        )
        drawBar(in: top, window: entry.session, now: now)
        drawBar(in: top.offsetBy(dx: 0, dy: barSize.height + barGap), window: entry.weekly, now: now)

        if let text {
            let textSize = text.size()
            text.draw(at: NSPoint(x: x + barSize.width + textGap, y: (height - textSize.height) / 2))
        }
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
