import ClaudeUsageCore
import Combine
import Foundation

/// Tracks the prompt cache of every running Claude Code session and notifies shortly before one expires.
@MainActor
final class CacheMonitor: ObservableObject {
    @Published private(set) var sessions: [CacheSession] = []

    private let settings: AppSettings
    private let notifier: UsageNotifier
    private let scanner = TranscriptScanner()
    /// Session id → the expiry an alert was sent for, so each expiry window alerts once.
    private var alerted: [CacheSession.ID: Date] = [:]
    private var watcher: TranscriptWatcher?
    private var wakeTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    init(settings: AppSettings, notifier: UsageNotifier) {
        self.settings = settings
        self.notifier = notifier
        settings.$accounts
            .dropFirst()
            .sink { [weak self] accounts in self?.watch(accounts.map(\.url)) }
            .store(in: &subscriptions)
    }

    func start() {
        watcher = TranscriptWatcher { [weak self] in self?.scanNow() }
        watch(settings.accounts.map(\.url))
    }

    private func watch(_ configDirectories: [URL]) {
        watcher?.watch(configDirectories)
        scanNow()
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
        scheduleWake(for: found, now: now)
    }

    /// Transcripts don't change when an alert falls due or a cache expires, so scan again at the next of those moments.
    private func scheduleWake(for sessions: [CacheSession], now: Date) {
        wakeTask?.cancel()
        let moments = sessions.flatMap { [$0.expiresAt.addingTimeInterval(-PromptCache.alertLeadTime), $0.expiresAt] }
        guard let next = moments.filter({ $0 > now }).min() else { return }
        wakeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(next.timeIntervalSince(now)))
            guard !Task.isCancelled else { return }
            await self?.scan()
        }
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
        return settings.accounts.first { $0.owns(session) }?.name
    }
}

extension Account {
    func owns(_ session: CacheSession) -> Bool {
        url.standardizedFileURL == session.configDirectory.standardizedFileURL
    }
}
