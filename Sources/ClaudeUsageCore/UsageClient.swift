import Foundation

public enum UsageClientError: Error, Equatable {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case http(status: Int)
    case invalidResponse
}

public struct UsageClient: Sendable {
    public static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    private let session: URLSession
    private let userAgent: String

    public init(session: URLSession = .shared, claudeCodeVersion: String = ClaudeCodeVersion.detect()) {
        self.session = session
        self.userAgent = "claude-code/\(claudeCodeVersion)"
    }

    public func fetch(accessToken: String) async throws -> UsageReport {
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 20)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UsageClientError.invalidResponse }

        switch http.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(UsageReport.self, from: data)
            } catch {
                throw UsageClientError.invalidResponse
            }
        case 401, 403:
            throw UsageClientError.unauthorized
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw UsageClientError.rateLimited(retryAfter: retryAfter)
        default:
            throw UsageClientError.http(status: http.statusCode)
        }
    }
}

/// The usage endpoint rate-limits requests harshly unless they carry a `claude-code/<version>` User-Agent.
public enum ClaudeCodeVersion {
    static let fallback = "2.1.285"

    /// The native installer links `~/.local/bin/claude` to `~/.local/share/claude/versions/<version>`.
    public static func detect() -> String {
        let link = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/bin/claude")
        guard let target = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path) else { return fallback }
        let version = URL(fileURLWithPath: target).lastPathComponent
        return version.first?.isNumber == true ? version : fallback
    }
}
