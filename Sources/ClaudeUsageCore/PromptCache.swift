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
    public let lastRequest: Date

    public init(id: String, configDirectory: URL, title: String?, workingDirectory: String?, lastRequest: Date) {
        self.id = id
        self.configDirectory = configDirectory
        self.title = title
        self.workingDirectory = workingDirectory
        self.lastRequest = lastRequest
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

/// What the end of a transcript says about its session.
public struct TranscriptTail: Equatable {
    public var title: String?
    public var workingDirectory: String?
    public var lastRequest: Date?

    /// Parses JSONL lines; a partial first line (from reading only the tail) is skipped as invalid JSON.
    /// A `/rename` title wins over the generated one. Synthetic assistant lines (errors, interruptions)
    /// don't come from a completed request, so they don't count.
    public static func parse(_ data: Data) -> TranscriptTail {
        struct Line: Decodable {
            struct Message: Decodable {
                let model: String?
            }
            let type: String?
            let timestamp: String?
            let cwd: String?
            let customTitle: String?
            let aiTitle: String?
            let message: Message?
        }

        var tail = TranscriptTail()
        var customTitle: String?
        var aiTitle: String?
        let decoder = JSONDecoder()
        for line in data.split(separator: UInt8(ascii: "\n")) {
            guard let entry = try? decoder.decode(Line.self, from: line) else { continue }
            if let cwd = entry.cwd { tail.workingDirectory = cwd }
            switch entry.type {
            case "custom-title": customTitle = entry.customTitle ?? customTitle
            case "ai-title": aiTitle = entry.aiTitle ?? aiTitle
            case "assistant" where entry.message?.model != "<synthetic>":
                if let date = entry.timestamp.flatMap(UsageWindow.parseDate) {
                    tail.lastRequest = date
                }
            default: break
            }
        }
        tail.title = [customTitle, aiTitle].compactMap { $0 }.first { !$0.isEmpty }
        return tail
    }
}

/// Finds running Claude Code sessions whose prompt cache hasn't expired, from the transcripts in each config
/// folder's `projects/<project>/<session>.jsonl`. Only transcripts changed since the last scan are read.
public actor TranscriptScanner {
    static let tailSize = 256 * 1024

    private var cache: [URL: (modified: Date, session: CacheSession?)] = [:]

    public init() {}

    public func sessions(in configDirectories: [URL], now: Date) -> [CacheSession] {
        let recent = configDirectories.flatMap { directory in
            Self.transcripts(in: directory, modifiedAfter: now.addingTimeInterval(-PromptCache.ttl))
                .map { (configDirectory: directory, url: $0.url, modified: $0.modified) }
        }

        var next: [URL: (modified: Date, session: CacheSession?)] = [:]
        for transcript in recent {
            if let cached = cache[transcript.url], cached.modified == transcript.modified {
                next[transcript.url] = cached
            } else {
                let session = Self.session(at: transcript.url, configDirectory: transcript.configDirectory)
                next[transcript.url] = (transcript.modified, session)
            }
        }
        cache = next

        let running = Set(configDirectories.flatMap(Self.runningSessionIDs))
        return next.values
            .compactMap(\.session)
            .filter { !$0.isExpired(at: now) && running.contains(URL(fileURLWithPath: $0.id).deletingPathExtension().lastPathComponent) }
            .sorted { $0.expiresAt < $1.expiresAt }
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

    static func transcripts(in configDirectory: URL, modifiedAfter cutoff: Date) -> [(url: URL, modified: Date)] {
        let fileManager = FileManager.default
        let projects = configDirectory.appending(path: "projects", directoryHint: .isDirectory)
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let folders = (try? fileManager.contentsOfDirectory(at: projects, includingPropertiesForKeys: nil)) ?? []
        return folders.flatMap { folder in
            let files = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)) ?? []
            return files.compactMap { url -> (url: URL, modified: Date)? in
                guard url.pathExtension == "jsonl",
                      let modified = try? url.resourceValues(forKeys: Set(keys)).contentModificationDate,
                      modified > cutoff
                else { return nil }
                return (url, modified)
            }
        }
    }

    static func session(at url: URL, configDirectory: URL) -> CacheSession? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        try? handle.seek(toOffset: size > UInt64(tailSize) ? size - UInt64(tailSize) : 0)
        guard let data = try? handle.readToEnd() else { return nil }

        let tail = TranscriptTail.parse(data)
        guard let lastRequest = tail.lastRequest else { return nil }
        return CacheSession(
            id: url.path,
            configDirectory: configDirectory,
            title: tail.title,
            workingDirectory: tail.workingDirectory,
            lastRequest: lastRequest
        )
    }
}
