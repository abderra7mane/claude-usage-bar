import CoreServices
import Foundation

/// Calls `onChange` on the main actor when a transcript changes under a config folder's `projects`, or a
/// Claude Code process starts or quits, which updates its `sessions` registration.
final class TranscriptWatcher {
    /// Coalesces the burst of writes Claude Code makes during a turn into one call.
    private static let latency: CFTimeInterval = 2

    private let onChange: @MainActor @Sendable () -> Void
    private var projectPrefixes: [String] = []
    private var sessionPrefixes: [String] = []
    private var stream: FSEventStreamRef?

    init(onChange: @escaping @MainActor @Sendable () -> Void) {
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    func watch(_ configDirectories: [URL]) {
        stop()
        let directories = configDirectories.map(Self.realPath)
        projectPrefixes = directories.map { $0 + "/projects/" }
        sessionPrefixes = directories.map { $0 + "/sessions/" }
        guard !directories.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
            guard let info else { return }
            let watcher = Unmanaged<TranscriptWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
            let flags = UnsafeBufferPointer(start: flags, count: count)
            watcher.handle(paths: paths, flags: Array(flags))
        }
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            directories as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            Self.latency,
            flags
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func handle(paths: [String], flags: [FSEventStreamEventFlags]) {
        let dropped = flags.contains { $0 & FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs) != 0 }
        let relevant = paths.contains { path in
            (path.hasSuffix(".jsonl") && projectPrefixes.contains { path.hasPrefix($0) })
                || (path.hasSuffix(".json") && sessionPrefixes.contains { path.hasPrefix($0) })
        }
        guard dropped || relevant else { return }
        let onChange = onChange
        MainActor.assumeIsolated { onChange() }
    }

    /// FSEvents reports resolved paths, so prefixes must be resolved too.
    private static func realPath(_ url: URL) -> String {
        guard let resolved = realpath(url.path, nil) else { return url.path }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}
