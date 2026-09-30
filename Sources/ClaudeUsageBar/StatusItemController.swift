import AppKit
import ClaudeUsageCore
import Combine
import SwiftUI

/// A single menu bar item showing every account marked for the menu bar.
@MainActor
final class StatusItemController: NSObject {
    private let model: AppModel
    private let settings: AppSettings
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var subscriptions = Set<AnyCancellable>()
    private var clock: Timer?

    init(model: AppModel, openSettings: @escaping () -> Void) {
        self.model = model
        self.settings = model.settings
        super.init()

        let panel = UsagePanel(model: model, settings: settings) { [weak self] in
            self?.popover.performClose(nil)
            openSettings()
        }
        let hosting = NSHostingController(rootView: panel)
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient

        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.imagePosition = .imageOnly

        model.objectWillChange
            .merge(with: settings.objectWillChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.render() }
            .store(in: &subscriptions)

        // Keeps countdowns and passed resets current between fetches.
        clock = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.render() }
        }

        render()
    }

    private func render() {
        guard let button = statusItem.button else { return }
        let now = Date.now
        let shown = settings.accounts.filter(\.showInMenuBar)

        let entries = shown.map { account in
            let monitor = model.monitor(for: account)
            return StatusIcon.Entry(
                name: settings.showAccountNames ? account.name : nil,
                session: monitor?.report?.fiveHour,
                weekly: monitor?.report?.sevenDay,
                percentages: settings.showPercentages ? percentages(monitor?.report, now: now) : nil,
                dimmed: monitor?.problem?.needsLogin == true
            )
        }
        button.image = StatusIcon.image(entries: entries, now: now)
        button.toolTip = shown.isEmpty
            ? "Claude Usage Bar: no account shown in the menu bar"
            : shown.map { tooltip(account: $0, monitor: model.monitor(for: $0), now: now) }.joined(separator: "\n\n")
    }

    private func percentages(_ report: UsageReport?, now: Date) -> String {
        [report?.fiveHour, report?.sevenDay]
            .map { $0.map { UsageFormat.percent($0.effectiveUtilization(at: now)) } ?? "–" }
            .joined(separator: " · ")
    }

    private func tooltip(account: Account, monitor: UsageMonitor?, now: Date) -> String {
        func line(_ name: String, _ window: UsageWindow?) -> String {
            guard let window else { return "\(name): no data" }
            let percent = UsageFormat.percent(window.effectiveUtilization(at: now))
            return "\(name): \(percent), \(UsageFormat.reset(window.resetsAt, now: now).lowercased())"
        }
        var lines = [
            "\(account.name) (\(ConfigDirectory.displayPath(account.url)))",
            line("Session (5h)", monitor?.report?.fiveHour),
            line("Weekly", monitor?.report?.sevenDay),
        ]
        if let problem = monitor?.problem {
            lines.append(problem.message)
        }
        return lines.joined(separator: "\n")
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        model.refreshIfStale()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
        popover.contentViewController?.view.window?.makeKey()
    }
}
