import CryptoKit
import Foundation

/// A Claude Code config folder (`CLAUDE_CONFIG_DIR`), each holding its own login.
public enum ConfigDirectory {
    public static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    /// Where Claude Code keeps its config when `CLAUDE_CONFIG_DIR` is unset.
    public static var defaultURL: URL { home.appending(path: ".claude", directoryHint: .isDirectory) }

    public static func isDefault(_ url: URL) -> Bool {
        url.standardizedFileURL.path == defaultURL.standardizedFileURL.path
    }

    /// Keychain services Claude Code may have stored this folder's login under.
    /// With `CLAUDE_CONFIG_DIR` set, it appends the first 8 hex chars of the folder path's SHA-256.
    /// `~/.claude` also matches the hashed name, for when `CLAUDE_CONFIG_DIR` points at it explicitly.
    public static func keychainServices(for url: URL) -> [String] {
        let base = "Claude Code-credentials"
        let hashed = "\(base)-\(pathHash(url))"
        return isDefault(url) ? [base, hashed] : [hashed]
    }

    static func pathHash(_ url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.standardizedFileURL.path.utf8))
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(8))
    }

    /// Hidden `~/.claude*` folders that look like Claude Code config folders.
    public static func discover(in directory: URL = home) -> [URL] {
        let fileManager = FileManager.default
        let entries = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []
        return entries
            .filter { url in
                guard url.lastPathComponent.hasPrefix(".claude"),
                      (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                else { return false }
                return ["settings.json", "projects"].contains {
                    fileManager.fileExists(atPath: url.appending(path: $0).path)
                }
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// `.claude` → "default", `.claude-personal` → "personal", anything else → the folder name.
    public static func suggestedName(for url: URL) -> String {
        if isDefault(url) { return "default" }
        let folder = url.lastPathComponent
        for prefix in [".claude-", ".claude_", "."] where folder.hasPrefix(prefix) && folder.count > prefix.count {
            return String(folder.dropFirst(prefix.count))
        }
        return folder
    }

    /// Shell command that opens Claude Code on this folder, to log in or refresh the token.
    public static func loginCommand(for url: URL) -> String {
        if isDefault(url) { return "env -u CLAUDE_CONFIG_DIR claude" }
        let quoted = url.standardizedFileURL.path.replacingOccurrences(of: "'", with: "'\\''")
        return "CLAUDE_CONFIG_DIR='\(quoted)' claude"
    }

    /// `~/…` form of the path for display.
    public static func displayPath(_ url: URL) -> String {
        let path = url.standardizedFileURL.path
        let homePath = home.standardizedFileURL.path
        return path.hasPrefix(homePath + "/") ? "~" + path.dropFirst(homePath.count) : path
    }
}
