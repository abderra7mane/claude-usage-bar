import ClaudeUsageCore
import SwiftUI

/// One bar per running Claude Code session with a live prompt cache: full with an hour left, empty when it expires.
struct CacheTimersView: View {
    private static let rowHeight: CGFloat = 52
    private static let visibleRows = 8

    @ObservedObject var monitor: CacheMonitor

    var body: some View {
        TimelineView(.periodic(from: .now, by: 10)) { context in
            let sessions = monitor.sessions.filter { !$0.isExpired(at: context.date) }
            VStack(alignment: .leading, spacing: 14) {
                header(count: sessions.count)

                if sessions.isEmpty {
                    Text("No Claude Code session has a live prompt cache.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if sessions.count > Self.visibleRows {
                    ScrollView {
                        rows(sessions, now: context.date)
                    }
                    .frame(height: Self.rowHeight * CGFloat(Self.visibleRows))
                } else {
                    rows(sessions, now: context.date)
                }

                Text("A session's cache expires 1 hour after its last request. Send a message to keep it.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func header(count: Int) -> some View {
        HStack {
            Text("Prompt Caches").font(.headline)
            if count > 0 {
                Text("\(count)")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            Spacer()
        }
    }

    private func rows(_ sessions: [CacheSession], now: Date) -> some View {
        VStack(spacing: 0) {
            ForEach(sessions) { session in
                CacheTimerRow(session: session, accountName: monitor.accountName(for: session), now: now)
                    .frame(height: Self.rowHeight)
            }
        }
    }
}

private struct CacheTimerRow: View {
    let session: CacheSession
    let accountName: String?
    let now: Date

    var body: some View {
        let color = session.level(at: now).color

        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.title ?? session.projectName ?? "Untitled session")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text(UsageFormat.remaining(session.remaining(at: now)))
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
            UsageBar(fraction: session.fraction(at: now), color: color)
            Text(details)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .help("Expires at \(session.expiresAt.formatted(date: .omitted, time: .shortened))")
    }

    private var details: String {
        let path = session.workingDirectory.map { ConfigDirectory.displayPath(URL(fileURLWithPath: $0)) }
        return [accountName, path].compactMap { $0 }.joined(separator: " · ")
    }
}
