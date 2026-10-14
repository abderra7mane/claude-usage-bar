import ClaudeUsageCore
import Combine
import Foundation

/// Tracks the prompt cache of every recent Claude Code session and notifies shortly before one expires.
@MainActor
final class CacheMonitor: ObservableObject {
    static let scanInterval: TimeInterval = 30

    @Published private(set) var sessions: [CacheSession] = []

    private let settings: AppSettings
    private let notifier: UsageNotifier
    private let scanner = TranscriptScanner()
    /// Session id → the expiry an alert was sent for, so each expiry window alerts once.
    private var alerted: [CacheSession.ID: Date] = [:]
    private var scanTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    init(settings: AppSettings, notifier: UsageNotifier) {
        self.settings = settings
        self.notifier = notifier
        settings.$accounts
            .dropFirst()
            .sink { [weak self] _ in self?.scanNow() }
            .store(in: &subscriptions)
    }

    func start() {
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.scan()
                try? await Task.sleep(for: .seconds(Self.scanInterval))
            }
        }
    }

    func scanNow() {
        Task { await scan() }
    }

    private func scan() async {
        let now = Date.now
        let directories = settings.accounts.map(\.url)
        let found = await scanner.sessions(in: directories, now: now)
        sessions = found
        alertIfDue(found, now: now)
    }

    private func alertIfDue(_ sessions: [CacheSession], now: Date) {
        let current = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        for (id, expiry) in alerted where current[id]?.expiresAt != expiry {
            alerted[id] = nil
            notifier.removeCacheAlert(for: id)
        }

        guard settings.cacheAlertsEnabled else { return }
        for session in sessions where session.isAlertDue(at: now) && alerted[session.id] == nil {
            alerted[session.id] = session.expiresAt
            notifier.cacheExpiring(session, accountName: accountName(for: session), now: now)
        }
    }

    /// Only set when several accounts are configured.
    func accountName(for session: CacheSession) -> String? {
        guard settings.accounts.count > 1 else { return nil }
        return settings.accounts.first { $0.url.standardizedFileURL == session.configDirectory.standardizedFileURL }?.name
    }
}
