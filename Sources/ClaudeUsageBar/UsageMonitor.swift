import AppKit
import ClaudeUsageCore

@MainActor
final class UsageMonitor: ObservableObject {
    enum Problem: Equatable {
        case noCredentials
        case tokenExpired
        case unauthorized
        case rateLimited
        case failed(String)

        var message: String {
            switch self {
            case .noCredentials: "Not logged in. Open Claude Code on this folder and run /login."
            case .tokenExpired: "Token expired. Open Claude Code on this folder to refresh it, or run /login."
            case .unauthorized: "Login rejected. Open Claude Code on this folder and run /login."
            case .rateLimited: "Rate limited by Anthropic. Retrying later."
            case .failed(let reason): reason
            }
        }

        var shortMessage: String {
            switch self {
            case .noCredentials: "Not logged in"
            case .tokenExpired: "Token expired"
            case .unauthorized: "Login rejected"
            case .rateLimited: "Rate limited"
            case .failed: "Error"
            }
        }

        var needsLogin: Bool {
            switch self {
            case .noCredentials, .tokenExpired, .unauthorized: true
            case .rateLimited, .failed: false
            }
        }
    }

    static let retryInterval: TimeInterval = 60
    static let maxBackoff: TimeInterval = 900

    @Published private(set) var report: UsageReport?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var problem: Problem?
    @Published private(set) var plan: String?
    @Published private(set) var isRefreshing = false

    let configDirectory: URL
    var pollInterval: TimeInterval {
        didSet { if pollInterval != oldValue { reschedule() } }
    }
    private let client = UsageClient()
    private var pollTask: Task<Void, Never>?
    private var backoff: TimeInterval

    init(configDirectory: URL, pollInterval: TimeInterval) {
        self.configDirectory = configDirectory
        self.pollInterval = pollInterval
        backoff = pollInterval
    }

    func start() {
        schedule(after: 0)
    }

    private func schedule(after initialDelay: TimeInterval) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            var delay = initialDelay
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let next = await self?.refresh() else { return }
                delay = next
            }
        }
    }

    /// Applies a new poll interval to the pending wait, counted from the last successful refresh.
    /// Retry and backoff waits are left as they are.
    private func reschedule() {
        guard pollTask != nil, !isRefreshing, problem == nil, let lastUpdated else { return }
        backoff = pollInterval
        schedule(after: max(0, pollInterval - Date.now.timeIntervalSince(lastUpdated)))
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Restarts polling so the manual refresh also resets the schedule.
    func refreshNow() {
        guard !isRefreshing else { return }
        start()
    }

    func refreshIfStale(olderThan age: TimeInterval = 60) {
        if let lastUpdated, Date.now.timeIntervalSince(lastUpdated) < age { return }
        refreshNow()
    }

    /// Returns the delay before the next refresh.
    private func refresh() async -> TimeInterval {
        isRefreshing = true
        defer { isRefreshing = false }

        let credentials: OAuthCredentials
        do {
            credentials = try await Task.detached { [configDirectory] in
                try CredentialsStore.load(configDirectory: configDirectory)
            }.value
        } catch {
            problem = .noCredentials
            report = nil
            plan = nil
            return Self.retryInterval
        }
        plan = credentials.subscriptionType
        guard !credentials.isExpired(at: .now) else {
            problem = .tokenExpired
            return Self.retryInterval
        }

        do {
            report = try await client.fetch(accessToken: credentials.accessToken)
            lastUpdated = .now
            problem = nil
            backoff = pollInterval
            return pollInterval
        } catch UsageClientError.unauthorized {
            problem = .unauthorized
            report = nil
            return Self.retryInterval
        } catch UsageClientError.rateLimited(let retryAfter) {
            problem = .rateLimited
            backoff = min(backoff * 2, max(Self.maxBackoff, pollInterval))
            return max(retryAfter ?? 0, backoff)
        } catch UsageClientError.http(let status) {
            problem = .failed("Anthropic returned HTTP \(status).")
            return Self.retryInterval
        } catch UsageClientError.invalidResponse {
            problem = .failed("Unexpected response from Anthropic.")
            return Self.retryInterval
        } catch {
            if Task.isCancelled { return pollInterval }
            problem = .failed(error.localizedDescription)
            return Self.retryInterval
        }
    }
}
