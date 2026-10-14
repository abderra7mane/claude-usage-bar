import ClaudeUsageCore
import SwiftUI

/// Running Claude Code sessions with a live prompt cache, grouped by account. Each row shows the session's cost and a
/// bar that is full with an hour left and empty when the cache expires.
struct SessionsView: View {
    private static let visibleRows = 8

    @ObservedObject var monitor: CacheMonitor
    @ObservedObject var settings: AppSettings

    var body: some View {
        TimelineView(.periodic(from: .now, by: 10)) { context in
            let sessions = monitor.sessions.filter { !$0.isExpired(at: context.date) }
            VStack(alignment: .leading, spacing: 14) {
                header(count: sessions.count)

                if settings.accounts.isEmpty {
                    Text("No accounts yet. Add a Claude config folder in Settings.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if sessions.count > Self.visibleRows {
                    ScrollView {
                        accounts(sessions, now: context.date)
                    }
                    .frame(height: SessionRow.height * CGFloat(Self.visibleRows))
                } else {
                    accounts(sessions, now: context.date)
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
            Text("Claude Sessions").font(.headline)
            if count > 0 {
                CountBadge(count: count)
            }
            Spacer()
            Button {
                monitor.scanNow()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
    }

    private func accounts(_ sessions: [CacheSession], now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(settings.accounts) { account in
                Divider()
                AccountSessions(account: account, sessions: sessions.filter(account.owns), now: now)
            }
        }
    }
}

private struct AccountSessions: View {
    let account: Account
    let sessions: [CacheSession]
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if sessions.isEmpty {
                Text("No session has a live prompt cache.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions) { session in
                        SessionRow(session: session, now: now)
                            .frame(height: SessionRow.height)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(account.name).font(.subheadline.weight(.bold))
            Text(ConfigDirectory.displayPath(account.url))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if !sessions.isEmpty {
                CountBadge(count: sessions.count)
            }
        }
    }
}

private struct CountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }
}

private struct SessionRow: View {
    static let height: CGFloat = 52

    let session: CacheSession
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
                HStack(spacing: 4) {
                    Text(UsageFormat.cost(session.cost))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(UsageFormat.remaining(session.remaining(at: now)))
                        .foregroundStyle(color)
                }
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .monospacedDigit()
            }
            UsageBar(fraction: session.fraction(at: now), color: color)
            if let path = session.workingDirectory {
                Text(ConfigDirectory.displayPath(URL(fileURLWithPath: path)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .help("Expires at \(session.expiresAt.formatted(date: .omitted, time: .shortened))")
    }
}
