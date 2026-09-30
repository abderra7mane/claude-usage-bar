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

    static let pollInterval: TimeInterval = 180
    static let retryInterval: TimeInterval = 60
    static let maxBackoff: TimeInterval = 900

    @Published private(set) var report: UsageReport?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var problem: Problem?
    @Published private(set) var plan: String?
    @Published private(set) var isRefreshing = false

    let configDirectory: URL
    private let client = UsageClient()
    private var pollTask: Task<Void, Never>?
    private var backoff = pollInterval

    init(configDirectory: URL) {
        self.configDirectory = configDirectory
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let delay = await self?.refresh() else { return }
                try? await Task.sleep(for: .seconds(delay))
            }
        }
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
            backoff = Self.pollInterval
            return Self.pollInterval
        } catch UsageClientError.unauthorized {
            problem = .unauthorized
            report = nil
            return Self.retryInterval
        } catch UsageClientError.rateLimited(let retryAfter) {
            problem = .rateLimited
            backoff = min(backoff * 2, Self.maxBackoff)
            return max(retryAfter ?? 0, backoff)
        } catch UsageClientError.http(let status) {
            problem = .failed("Anthropic returned HTTP \(status).")
            return Self.retryInterval
        } catch UsageClientError.invalidResponse {
            problem = .failed("Unexpected response from Anthropic.")
            return Self.retryInterval
        } catch {
            if Task.isCancelled { return Self.pollInterval }
            problem = .failed(error.localizedDescription)
            return Self.retryInterval
        }
    }
}
