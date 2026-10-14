import Foundation

/// Claude Code's prompt cache lives one hour after a session's last API request.
public enum PromptCache {
    public static let ttl: TimeInterval = 3600
    public static let alertLeadTime: TimeInterval = 300
    static let warningTime: TimeInterval = 900
}

public struct CacheSession: Sendable, Equatable, Identifiable {
    /// The transcript path, unique across config folders.
    public let id: String
    public let configDirectory: URL
    public let title: String?
    public let workingDirectory: String?
    public let startedAt: Date
    public let lastRequest: Date
    /// Estimated at API prices, subagents included.
    public let cost: Double

    public init(id: String, configDirectory: URL, title: String?, workingDirectory: String?, startedAt: Date, lastRequest: Date, cost: Double = 0) {
        self.id = id
        self.configDirectory = configDirectory
        self.title = title
        self.workingDirectory = workingDirectory
        self.startedAt = startedAt
        self.lastRequest = lastRequest
        self.cost = cost
    }

    public var expiresAt: Date { lastRequest.addingTimeInterval(PromptCache.ttl) }

    public var projectName: String? {
        workingDirectory.map { URL(fileURLWithPath: $0).lastPathComponent }
    }

    public func remaining(at now: Date) -> TimeInterval {
        max(0, expiresAt.timeIntervalSince(now))
    }

    /// 1 with the full hour left, 0 once expired.
    public func fraction(at now: Date) -> Double {
        remaining(at: now) / PromptCache.ttl
    }

    public func isExpired(at now: Date) -> Bool {
        remaining(at: now) == 0
    }

    public func isAlertDue(at now: Date) -> Bool {
        let remaining = remaining(at: now)
        return remaining > 0 && remaining <= PromptCache.alertLeadTime
    }

    public func level(at now: Date) -> UsageLevel {
        switch remaining(at: now) {
        case ...PromptCache.alertLeadTime: .critical
        case ...PromptCache.warningTime: .warning
        default: .ok
        }
    }
}

/// What a transcript says about its session, built up as lines are appended.
public struct TranscriptSummary: Equatable {
    public private(set) var workingDirectory: String?
    /// The timestamp of the first line.
    public private(set) var startedAt: Date?
    public private(set) var lastRequest: Date?
    public private(set) var cost: Double = 0
    private var customTitle: String?
    private var aiTitle: String?
    /// Claude Code writes one line per content block, each repeating the response's usage.
    private var countedResponses: Set<String> = []

    public init() {}

    /// A `/rename` title wins over the generated one.
    public var title: String? {
        [customTitle, aiTitle].compactMap { $0 }.first { !$0.isEmpty }
    }

    /// Reads JSONL lines, skipping any that aren't valid JSON. Synthetic assistant lines (errors,
    /// interruptions) don't come from a completed request, so they don't count as one.
    public mutating func consume(_ data: Data) {
        struct Line: Decodable {
            struct Message: Decodable {
                let id: String?
                let model: String?
                let usage: TokenUsage?
            }
            let type: String?
            let timestamp: String?
            let cwd: String?
            let customTitle: String?
            let aiTitle: String?
            let requestId: String?
            let message: Message?
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        for line in data.split(separator: UInt8(ascii: "\n")) {
            guard let entry = try? decoder.decode(Line.self, from: line) else { continue }
            if let cwd = entry.cwd { workingDirectory = cwd }
            if startedAt == nil { startedAt = entry.timestamp.flatMap(UsageWindow.parseDate) }
            switch entry.type {
            case "custom-title": customTitle = entry.customTitle ?? customTitle
            case "ai-title": aiTitle = entry.aiTitle ?? aiTitle
            case "assistant" where entry.message?.model != "<synthetic>":
                if let date = entry.timestamp.flatMap(UsageWindow.parseDate) {
                    lastRequest = date
                }
                if let message = entry.message {
                    addCost(of: message.usage, model: message.model, response: message.id ?? entry.requestId)
                }
            default: break
            }
        }
    }

    private mutating func addCost(of usage: TokenUsage?, model: String?, response: String?) {
        guard let usage, let pricing = model.flatMap(ModelPricing.forModel) else { return }
        if let response {
            guard countedResponses.insert(response).inserted else { return }
        }
        cost += pricing.cost(of: usage)
    }
}

/// A transcript read up to `offset`, so the next read only parses what was appended since.
struct TrackedTranscript {
    private(set) var offset: UInt64 = 0
    private(set) var summary = TranscriptSummary()

    /// Leaves a partly written last line for the next read. Starts over if the file shrank.
    mutating func update(from url: URL) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd(), size != offset else { return }
        if size < offset { self = TrackedTranscript() }
        guard (try? handle.seek(toOffset: offset)) != nil,
              let data = try? handle.readToEnd(),
              let end = data.lastIndex(of: UInt8(ascii: "\n"))
        else { return }
        let complete = data[...end]
        summary.consume(complete)
        offset += UInt64(complete.count)
    }
}

/// Finds running Claude Code sessions whose prompt cache hasn't expired, from the transcripts in each config
/// folder's `projects/<project>/<session>.jsonl`, and adds up their cost with their subagents' transcripts in
/// `<session>/subagents/`. Each transcript is read incrementally, so only appended lines are parsed.
public actor TranscriptScanner {
    private var tracked: [URL: TrackedTranscript] = [:]

    public init() {}

    public func sessions(in configDirectories: [URL], now: Date) -> [CacheSession] {
        let running = Set(configDirectories.flatMap(Self.runningSessionIDs))
        let transcripts = configDirectories.flatMap { directory in
            Self.transcripts(in: directory, modifiedAfter: now.addingTimeInterval(-PromptCache.ttl))
                .filter { running.contains($0.deletingPathExtension().lastPathComponent) }
                .map { (configDirectory: directory, url: $0) }
        }

        var next: [URL: TrackedTranscript] = [:]
        var sessions: [CacheSession] = []
        for transcript in transcripts {
            let summary = read(transcript.url, into: &next)
            let subagentsCost = Self.subagentTranscripts(of: transcript.url)
                .map { read($0, into: &next).cost }
                .reduce(0, +)
            guard let lastRequest = summary.lastRequest else { continue }
            sessions.append(CacheSession(
                id: transcript.url.path,
                configDirectory: transcript.configDirectory,
                title: summary.title,
                workingDirectory: summary.workingDirectory,
                startedAt: summary.startedAt ?? lastRequest,
                lastRequest: lastRequest,
                cost: summary.cost + subagentsCost
            ))
        }
        tracked = next

        return sessions
            .filter { !$0.isExpired(at: now) }
            .sorted { $0.startedAt < $1.startedAt }
    }

    private func read(_ url: URL, into next: inout [URL: TrackedTranscript]) -> TranscriptSummary {
        var transcript = tracked[url] ?? TrackedTranscript()
        transcript.update(from: url)
        next[url] = transcript
        return transcript.summary
    }

    /// Claude Code registers each running process in `<config>/sessions/<pid>.json` with the id of the
    /// session it has open. A process that crashed can leave its file behind, so the pid must still be alive.
    static func runningSessionIDs(in configDirectory: URL) -> [String] {
        struct Registration: Decodable {
            let pid: Int32
            let sessionId: String
        }

        let folder = configDirectory.appending(path: "sessions", directoryHint: .isDirectory)
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.compactMap { url in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let registration = try? JSONDecoder().decode(Registration.self, from: data),
                  kill(registration.pid, 0) == 0 || errno == EPERM
            else { return nil }
            return registration.sessionId
        }
    }

    static func transcripts(in configDirectory: URL, modifiedAfter cutoff: Date) -> [URL] {
        let fileManager = FileManager.default
        let projects = configDirectory.appending(path: "projects", directoryHint: .isDirectory)
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let folders = (try? fileManager.contentsOfDirectory(at: projects, includingPropertiesForKeys: nil)) ?? []
        return folders.flatMap { folder in
            let files = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)) ?? []
            return files.filter { url in
                guard url.pathExtension == "jsonl",
                      let modified = try? url.resourceValues(forKeys: Set(keys)).contentModificationDate
                else { return false }
                return modified > cutoff
            }
        }
    }

    static func subagentTranscripts(of transcript: URL) -> [URL] {
        let folder = transcript.deletingPathExtension().appending(path: "subagents", directoryHint: .isDirectory)
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "jsonl" }
    }
}
