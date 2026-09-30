import Foundation

public struct OAuthCredentials: Sendable, Equatable {
    public let accessToken: String
    public let expiresAt: Date?
    public let subscriptionType: String?

    public init(accessToken: String, expiresAt: Date?, subscriptionType: String?) {
        self.accessToken = accessToken
        self.expiresAt = expiresAt
        self.subscriptionType = subscriptionType
    }

    public func isExpired(at now: Date, leeway: TimeInterval = 60) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt.addingTimeInterval(-leeway) <= now
    }

    /// Parses the JSON Claude Code stores: `{"claudeAiOauth": {"accessToken", "expiresAt" (ms), "subscriptionType"}}`.
    public static func parse(_ data: Data) throws -> OAuthCredentials {
        struct Stored: Decodable {
            struct OAuth: Decodable {
                let accessToken: String
                let expiresAt: Double?
                let subscriptionType: String?
            }
            let claudeAiOauth: OAuth
        }
        let oauth = try JSONDecoder().decode(Stored.self, from: data).claudeAiOauth
        return OAuthCredentials(
            accessToken: oauth.accessToken,
            expiresAt: oauth.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) },
            subscriptionType: oauth.subscriptionType
        )
    }
}

public enum CredentialsError: Error, Equatable {
    case notFound
}

/// Reads the OAuth credentials Claude Code keeps for a config folder: the login keychain first,
/// then `<folder>/.credentials.json`.
public enum CredentialsStore {
    public static func load(configDirectory: URL) throws -> OAuthCredentials {
        for service in ConfigDirectory.keychainServices(for: configDirectory) {
            if let data = readKeychain(service: service), let credentials = try? OAuthCredentials.parse(data) {
                return credentials
            }
        }
        if let data = readFile(configDirectory: configDirectory), let credentials = try? OAuthCredentials.parse(data) {
            return credentials
        }
        throw CredentialsError.notFound
    }

    /// Uses `/usr/bin/security` so keychain access is granted to that tool, not to this app,
    /// whose ad-hoc signature changes on every rebuild and would trigger a new prompt each time.
    static func readKeychain(service: String) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", service, "-w"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, !data.isEmpty else { return nil }
        return data
    }

    static func readFile(configDirectory: URL) -> Data? {
        try? Data(contentsOf: configDirectory.appending(path: ".credentials.json"))
    }
}
