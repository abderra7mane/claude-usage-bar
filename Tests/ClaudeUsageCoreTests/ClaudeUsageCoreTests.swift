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

struct UsageAlertTests {
    @Test(arguments: [
        (70.0, 74.9, nil),
        (74.0, 76.0, 75.0),
        (74.9, 75.0, 75.0),
        (75.0, 79.0, nil),
        (76.0, 76.0, nil),
        (74.0, 92.0, 90.0),
        (96.0, 120.0, 100.0),
        (90.0, 10.0, nil),
        (0.0, 100.0, 100.0),
    ] as [(Double, Double, Double?)])
    func crossedThreshold(previous: Double, current: Double, expected: Double?) {
        #expect(UsageAlert.threshold(crossedFrom: previous, to: current) == expected)
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

struct PromptCacheTests {
    let lastRequest = Date(timeIntervalSince1970: 100_000)

    var session: CacheSession {
        CacheSession(
            id: "/tmp/s.jsonl",
            configDirectory: URL(fileURLWithPath: "/tmp"),
            title: nil,
            workingDirectory: "/Users/me/Projects/app",
            lastRequest: lastRequest
        )
    }

    @Test func expiresAnHourAfterTheLastRequest() {
        #expect(session.expiresAt == lastRequest.addingTimeInterval(3600))
        #expect(session.fraction(at: lastRequest) == 1)
        #expect(session.fraction(at: lastRequest.addingTimeInterval(1800)) == 0.5)
        #expect(session.isExpired(at: lastRequest.addingTimeInterval(3600)))
        #expect(session.fraction(at: lastRequest.addingTimeInterval(4000)) == 0)
        #expect(session.projectName == "app")
    }

    @Test(arguments: [
        (2699.0, false, UsageLevel.ok),
        (3299.0, false, .warning),
        (3300.0, true, .critical),
        (2701.0, false, .warning),
        (3599.0, true, .critical),
        (3600.0, false, .critical),
    ])
    func alertsInTheLastFiveMinutes(elapsed: Double, due: Bool, level: UsageLevel) {
        let now = lastRequest.addingTimeInterval(elapsed)
        #expect(session.isAlertDue(at: now) == due)
        #expect(session.level(at: now) == level)
    }
}

struct TranscriptTailTests {
    @Test func readsTitleDirectoryAndLastRequest() throws {
        let lines = """
        al","cwd":"/partial"}
        {"type":"ai-title","aiTitle":"Generated title","sessionId":"s"}
        {"type":"assistant","timestamp":"2026-10-14T10:46:45.444Z","cwd":"/a","message":{"model":"claude-opus-5-5"}}
        {"type":"custom-title","customTitle":"Renamed","sessionId":"s"}
        {"type":"user","timestamp":"2026-10-14T10:50:00.000Z","cwd":"/b"}
        {"type":"assistant","timestamp":"2026-10-14T10:51:00.000Z","cwd":"/b","message":{"model":"<synthetic>"}}
        {"type":"mode","mode":"normal","sessionId":"s"}
        """
        let tail = TranscriptTail.parse(Data(lines.utf8))

        #expect(tail.title == "Renamed")
        #expect(tail.workingDirectory == "/b")
        let lastRequest = try #require(tail.lastRequest)
        #expect(abs(lastRequest.timeIntervalSince1970 - 1_791_974_805.444) < 0.001)
    }

    @Test func withoutRequestsHasNoLastRequest() {
        let tail = TranscriptTail.parse(Data(#"{"type":"user","timestamp":"2026-10-14T10:50:00Z","cwd":"/b"}"#.utf8))

        #expect(tail.lastRequest == nil)
        #expect(tail.title == nil)
    }

    @Test func scansRecentTranscripts() async throws {
        let fileManager = FileManager.default
        let config = fileManager.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? fileManager.removeItem(at: config) }
        let project = config.appending(path: "projects/-tmp-app")
        try fileManager.createDirectory(at: project, withIntermediateDirectories: true)

        let now = Date.now
        func write(_ name: String, lastRequest: Date) throws {
            let timestamp = lastRequest.formatted(.iso8601)
            let line = #"{"type":"assistant","timestamp":"\#(timestamp)","cwd":"/tmp/app","message":{"model":"m"}}"#
            let url = project.appending(path: name)
            try Data(line.utf8).write(to: url)
            try fileManager.setAttributes([.modificationDate: lastRequest], ofItemAtPath: url.path)
        }
        try write("live.jsonl", lastRequest: now.addingTimeInterval(-600))
        try write("soon.jsonl", lastRequest: now.addingTimeInterval(-3400))
        try write("expired.jsonl", lastRequest: now.addingTimeInterval(-4000))
        try Data("{}".utf8).write(to: project.appending(path: "notes.txt"))
        let registry = config.appending(path: "sessions")
        try fileManager.createDirectory(at: registry, withIntermediateDirectories: true)
        let pid = ProcessInfo.processInfo.processIdentifier
        for (index, id) in ["live", "soon", "expired"].enumerated() {
            try Data(#"{"pid":\#(pid),"sessionId":"\#(id)"}"#.utf8).write(to: registry.appending(path: "\(index).json"))
        }

        let sessions = await TranscriptScanner().sessions(in: [config], now: now)

        #expect(sessions.map { URL(fileURLWithPath: $0.id).lastPathComponent } == ["soon.jsonl", "live.jsonl"])
        #expect(sessions.allSatisfy { $0.configDirectory == config && $0.workingDirectory == "/tmp/app" })
    }

    @Test func skipsSessionsWithoutARunningProcess() async throws {
        let fileManager = FileManager.default
        let config = fileManager.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? fileManager.removeItem(at: config) }
        let project = config.appending(path: "projects/-tmp-app")
        let registry = config.appending(path: "sessions")
        try fileManager.createDirectory(at: project, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: registry, withIntermediateDirectories: true)

        let timestamp = Date.now.addingTimeInterval(-600).formatted(.iso8601)
        for name in ["open", "closed", "crashed"] {
            let line = #"{"type":"assistant","timestamp":"\#(timestamp)","message":{"model":"m"}}"#
            try Data(line.utf8).write(to: project.appending(path: "\(name).jsonl"))
        }
        let alive = ProcessInfo.processInfo.processIdentifier
        try Data(#"{"pid":\#(alive),"sessionId":"open"}"#.utf8).write(to: registry.appending(path: "\(alive).json"))
        try Data(#"{"pid":99999999,"sessionId":"crashed"}"#.utf8).write(to: registry.appending(path: "99999999.json"))

        let sessions = await TranscriptScanner().sessions(in: [config], now: .now)

        #expect(sessions.map { URL(fileURLWithPath: $0.id).lastPathComponent } == ["open.jsonl"])
    }
}
