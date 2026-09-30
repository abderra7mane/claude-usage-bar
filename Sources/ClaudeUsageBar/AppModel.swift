import Combine
import Foundation

/// Keeps one running `UsageMonitor` per configured account.
@MainActor
final class AppModel: ObservableObject {
    let settings: AppSettings
    private(set) var monitors: [Account.ID: UsageMonitor] = [:]
    private var monitorSubscriptions: [Account.ID: AnyCancellable] = [:]
    private var subscriptions = Set<AnyCancellable>()

    init(settings: AppSettings) {
        self.settings = settings
        settings.$accounts
            .sink { [weak self] accounts in self?.sync(with: accounts) }
            .store(in: &subscriptions)
        settings.$refreshInterval
            .sink { [weak self] interval in self?.monitors.values.forEach { $0.pollInterval = interval } }
            .store(in: &subscriptions)
    }

    func monitor(for account: Account) -> UsageMonitor? {
        monitors[account.id]
    }

    func refreshAll() {
        monitors.values.forEach { $0.refreshNow() }
    }

    func refreshIfStale() {
        monitors.values.forEach { $0.refreshIfStale() }
    }

    private func sync(with accounts: [Account]) {
        let ids = Set(accounts.map(\.id))
        for id in monitors.keys where !ids.contains(id) {
            monitors.removeValue(forKey: id)?.stop()
            monitorSubscriptions[id] = nil
        }
        for account in accounts where monitors[account.id] == nil {
            let monitor = UsageMonitor(configDirectory: account.url, pollInterval: settings.refreshInterval)
            monitors[account.id] = monitor
            monitorSubscriptions[account.id] = monitor.objectWillChange
                .sink { [weak self] in self?.objectWillChange.send() }
            monitor.start()
        }
        objectWillChange.send()
    }
}
