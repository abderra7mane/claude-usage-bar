import Foundation
import Testing
@testable import ClaudeUsageCore

struct UsageLevelTests {
    @Test(arguments: [
        (0.0, UsageLevel.ok),
        (74.9, .ok),
        (75.0, .warning),
        (99.9, .warning),
        (100.0, .critical),
        (130.0, .critical),
    ])
    func thresholds(utilization: Double, expected: UsageLevel) {
        #expect(UsageLevel(utilization: utilization) == expected)
    }
}

struct UsageReportTests {
    let json = """
    {
        "five_hour": {"utilization": 33.0, "resets_at": "2026-04-11T07:00:00.528743+00:00"},
        "seven_day": {"utilization": 13.0, "resets_at": "2026-04-17T00:59:59+00:00"},
        "seven_day_opus": null,
        "seven_day_sonnet": {"utilization": 1.0, "resets_at": "2026-04-16T03:00:00.951719+00:00"},
        "extra_usage": {"is_enabled": false, "monthly_limit": null, "used_credits": null, "utilization": null}
    }
    """

    @Test func decodesWindows() throws {
        let report = try JSONDecoder().decode(UsageReport.self, from: Data(json.utf8))

        #expect(report.fiveHour?.utilization == 33)
        #expect(report.sevenDay?.utilization == 13)
        let fiveHourReset = try #require(report.fiveHour?.resetsAt)
        #expect(abs(fiveHourReset.timeIntervalSince1970 - 1_775_890_800.528) < 0.001)
        #expect(report.sevenDay?.resetsAt == Date(timeIntervalSince1970: 1_776_387_599))
    }

    @Test func decodesMissingAndNullResets() throws {
        let json = #"{"five_hour": {"utilization": 0.0, "resets_at": null}, "seven_day": null}"#
        let report = try JSONDecoder().decode(UsageReport.self, from: Data(json.utf8))

        #expect(report.fiveHour?.resetsAt == nil)
        #expect(report.sevenDay == nil)
    }

    @Test func passedResetCountsAsZero() {
        let resetsAt = Date(timeIntervalSince1970: 1000)
        let window = UsageWindow(utilization: 100, resetsAt: resetsAt)

        #expect(window.effectiveUtilization(at: resetsAt.addingTimeInterval(-1)) == 100)
        #expect(window.level(at: resetsAt.addingTimeInterval(-1)) == .critical)
        #expect(window.effectiveUtilization(at: resetsAt) == 0)
        #expect(window.level(at: resetsAt) == .ok)
    }
}

struct CredentialsTests {
    @Test func parsesClaudeCodeCredentials() throws {
        let json = """
        {"claudeAiOauth": {"accessToken": "token", "refreshToken": "refresh", "expiresAt": 1775890800000, "scopes": ["user:inference"], "subscriptionType": "max"}}
        """
        let credentials = try OAuthCredentials.parse(Data(json.utf8))

        #expect(credentials.accessToken == "token")
        #expect(credentials.expiresAt == Date(timeIntervalSince1970: 1_775_890_800))
        #expect(credentials.subscriptionType == "max")
    }

    @Test func expiryUsesLeeway() {
        let expiresAt = Date(timeIntervalSince1970: 10_000)
        let credentials = OAuthCredentials(accessToken: "token", expiresAt: expiresAt, subscriptionType: nil)

        #expect(!credentials.isExpired(at: expiresAt.addingTimeInterval(-61)))
        #expect(credentials.isExpired(at: expiresAt.addingTimeInterval(-60)))
    }

    @Test func rejectsUnrelatedJSON() {
        #expect(throws: DecodingError.self) {
            try OAuthCredentials.parse(Data(#"{"other": {}}"#.utf8))
        }
    }
}

struct ConfigDirectoryTests {
    @Test func hashesCustomFolderPath() {
        let url = URL(fileURLWithPath: "/tmp/home/.claude-work", isDirectory: true)

        #expect(ConfigDirectory.keychainServices(for: url) == ["Claude Code-credentials-f6b00124"])
    }

    @Test func defaultFolderTriesPlainNameFirst() {
        let services = ConfigDirectory.keychainServices(for: ConfigDirectory.defaultURL)

        #expect(services.first == "Claude Code-credentials")
        #expect(services.count == 2)
    }

    @Test(arguments: [
        (".claude", "default"),
        (".claude-personal", "personal"),
        (".claude_work", "work"),
        ("work-claude", "work-claude"),
    ])
    func suggestsNames(folder: String, expected: String) {
        let url = folder == ".claude"
            ? ConfigDirectory.defaultURL
            : URL(fileURLWithPath: "/tmp/home").appending(path: folder)

        #expect(ConfigDirectory.suggestedName(for: url) == expected)
    }

    @Test func loginCommands() {
        #expect(ConfigDirectory.loginCommand(for: ConfigDirectory.defaultURL) == "env -u CLAUDE_CONFIG_DIR claude")
        #expect(
            ConfigDirectory.loginCommand(for: URL(fileURLWithPath: "/tmp/it's/.claude-x"))
                == #"CLAUDE_CONFIG_DIR='/tmp/it'\''s/.claude-x' claude"#
        )
    }

    @Test func discoversConfigFolders() throws {
        let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: home.appending(path: ".claude-b/projects"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: home.appending(path: ".claude-a"), withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: home.appending(path: ".claude-a/settings.json"))
        try fileManager.createDirectory(at: home.appending(path: ".claude-empty"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: home.appending(path: ".other/projects"), withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: home.appending(path: ".claude.json"))

        let found = ConfigDirectory.discover(in: home).map(\.lastPathComponent)

        #expect(found == [".claude-a", ".claude-b"])
    }
}
