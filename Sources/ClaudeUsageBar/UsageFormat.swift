import AppKit
import ClaudeUsageCore
import SwiftUI

extension UsageLevel {
    var nsColor: NSColor {
        switch self {
        case .ok: .systemBlue
        case .warning: .systemOrange
        case .critical: .systemRed
        }
    }

    var color: Color { Color(nsColor: nsColor) }
}

enum UsageFormat {
    static func percent(_ utilization: Double) -> String {
        "\(Int(utilization.rounded()))%"
    }

    static func reset(_ date: Date?, now: Date) -> String {
        guard let date else { return "No reset scheduled" }
        let remaining = date.timeIntervalSince(now)
        guard remaining > 0 else { return "Reset, waiting for update" }
        guard remaining < 24 * 3600 else {
            return "Resets \(date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))"
        }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        return hours > 0 ? "Resets in \(hours)h \(minutes)m" : "Resets in \(max(minutes, 1))m"
    }

    static func updated(_ date: Date?, now: Date) -> String {
        guard let date else { return "Not updated yet" }
        let seconds = now.timeIntervalSince(date)
        return seconds < 60 ? "Updated just now" : "Updated \(Int(seconds / 60))m ago"
    }
}
