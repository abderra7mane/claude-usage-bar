import ClaudeUsageCore
import Foundation
import ServiceManagement

struct Account: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    let path: String
    var showInMenuBar: Bool

    var url: URL { URL(fileURLWithPath: path, isDirectory: true) }

    init(url: URL) {
        id = UUID()
        name = ConfigDirectory.suggestedName(for: url)
        path = url.standardizedFileURL.path
        showInMenuBar = true
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let accounts = "accounts"
        static let showPercentages = "showPercentages"
        static let showAccountNames = "showAccountNames"
        static let refreshInterval = "refreshInterval"
    }

    static let refreshIntervalOptions: [TimeInterval] = [60, 120, 180, 300, 600, 900]

    @Published var accounts: [Account] {
        didSet { saveAccounts() }
    }

    @Published var showPercentages: Bool {
        didSet { UserDefaults.standard.set(showPercentages, forKey: Key.showPercentages) }
    }

    @Published var showAccountNames: Bool {
        didSet { UserDefaults.standard.set(showAccountNames, forKey: Key.showAccountNames) }
    }

    @Published var refreshInterval: TimeInterval {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: Key.refreshInterval) }
    }

    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var launchAtLoginError: String?

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Key.showPercentages: true,
            Key.showAccountNames: true,
            Key.refreshInterval: 180,
        ])
        showPercentages = defaults.bool(forKey: Key.showPercentages)
        showAccountNames = defaults.bool(forKey: Key.showAccountNames)
        refreshInterval = defaults.double(forKey: Key.refreshInterval)
        launchAtLogin = SMAppService.mainApp.status == .enabled

        if let data = defaults.data(forKey: Key.accounts),
           let stored = try? JSONDecoder().decode([Account].self, from: data) {
            accounts = stored
        } else {
            accounts = [Account(url: ConfigDirectory.defaultURL)]
            saveAccounts()
        }
    }

    private func saveAccounts() {
        UserDefaults.standard.set(try? JSONEncoder().encode(accounts), forKey: Key.accounts)
    }

    /// Detected config folders that aren't accounts yet.
    var suggestedFolders: [URL] {
        let added = Set(accounts.map(\.path))
        return ConfigDirectory.discover().filter { !added.contains($0.standardizedFileURL.path) }
    }

    func addAccount(at url: URL) {
        let account = Account(url: url)
        guard !accounts.contains(where: { $0.path == account.path }) else { return }
        accounts.append(account)
    }

    func removeAccount(id: Account.ID) {
        accounts.removeAll { $0.id == id }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
