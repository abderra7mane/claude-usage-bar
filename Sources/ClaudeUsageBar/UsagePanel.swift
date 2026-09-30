import ClaudeUsageCore
import SwiftUI

struct UsagePanel: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                content(now: context.date)
            }
            .padding(16)

            Divider()
            footer
        }
        .frame(width: 320)
    }

    private func content(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if settings.accounts.isEmpty {
                Text("No accounts yet. Add a Claude config folder in Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(settings.accounts) { account in
                if let monitor = model.monitor(for: account) {
                    Divider()
                    AccountSection(account: account, monitor: monitor, now: now)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Claude Usage").font(.headline)
            Spacer()
            Button {
                model.refreshAll()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh all")
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Button("Settings…", action: openSettings)
            Button("Quit Claude Usage Bar") { NSApp.terminate(nil) }
        }
        .buttonStyle(MenuRowButtonStyle())
        .padding(6)
    }
}

/// Full-width row highlighted on hover, like a menu item.
private struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MenuRow(configuration: configuration)
    }

    private struct MenuRow: View {
        let configuration: Configuration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .foregroundStyle(isHovered ? Color.white : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHovered ? Color.accentColor : .clear)
                        .opacity(configuration.isPressed ? 0.8 : 1)
                )
                .contentShape(Rectangle())
                .onHover { isHovered = $0 }
        }
    }
}

private struct AccountSection: View {
    let account: Account
    @ObservedObject var monitor: UsageMonitor
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if monitor.report != nil || monitor.problem == nil {
                WindowRow(title: "Session", subtitle: "5 hours", window: monitor.report?.fiveHour, now: now)
                WindowRow(title: "Weekly", subtitle: "7 days", window: monitor.report?.sevenDay, now: now)
            }

            if let problem = monitor.problem {
                ProblemView(problem: problem, configDirectory: account.url)
            }

            if monitor.report != nil {
                Text(UsageFormat.updated(monitor.lastUpdated, now: now))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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
            if let plan = monitor.plan {
                Text(plan.capitalized)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
    }
}

struct ProblemView: View {
    let problem: UsageMonitor.Problem
    let configDirectory: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(problem.message)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
            .font(.caption)

            if problem.needsLogin {
                CopyLoginCommandButton(configDirectory: configDirectory)
            }
        }
    }
}

struct CopyLoginCommandButton: View {
    let configDirectory: URL
    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(ConfigDirectory.loginCommand(for: configDirectory), forType: .string)
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                copied = false
            }
        } label: {
            Label(copied ? "Copied" : "Copy login command", systemImage: copied ? "checkmark" : "doc.on.doc")
        }
        .controlSize(.small)
        .help(ConfigDirectory.loginCommand(for: configDirectory))
    }
}

private struct WindowRow: View {
    let title: String
    let subtitle: String
    let window: UsageWindow?
    let now: Date

    var body: some View {
        let utilization = window?.effectiveUtilization(at: now)
        let color = window?.level(at: now).color ?? .secondary

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(utilization.map(UsageFormat.percent) ?? "–")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
            UsageBar(fraction: (utilization ?? 0) / 100, color: color)
            Text(window.map { UsageFormat.reset($0.resetsAt, now: now) } ?? "No data")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct UsageBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.2))
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 6)
    }
}
