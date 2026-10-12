import Combine
import Foundation
import Sparkle

/// Checks the GitHub releases appcast for updates. Disabled in builds without an update signing key.
@MainActor
final class Updater: ObservableObject {
    let isEnabled = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") != nil
    @Published private(set) var canCheckForUpdates = false
    /// A scheduled check found an update the user hasn't looked at yet.
    @Published private(set) var updateAvailable = false

    private let feed = ArchitectureFeed()
    private let reminder = UpdateReminder()
    private let controller: SPUStandardUpdaterController

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set {
            objectWillChange.send()
            controller.updater.automaticallyChecksForUpdates = newValue
        }
    }

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: feed,
            userDriverDelegate: reminder
        )
        reminder.onChange = { [weak self] in self?.updateAvailable = $0 }
        guard isEnabled else { return }
        controller.startUpdater()
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

/// Shows scheduled updates right away only when Sparkle would bring them into immediate focus, otherwise
/// leaves them to the menu bar indicator until the user checks for updates.
@MainActor
private final class UpdateReminder: NSObject, @preconcurrency SPUStandardUserDriverDelegate {
    var onChange: ((Bool) -> Void)?

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        if !handleShowingUpdate {
            onChange?(true)
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        onChange?(false)
    }

    func standardUserDriverWillFinishUpdateSession() {
        onChange?(false)
    }
}

/// Apple Silicon reads `SUFeedURL`; Intel reads its own appcast next to it. A universal build follows the
/// architecture it runs as, so it updates to that architecture's build.
private final class ArchitectureFeed: NSObject, SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        #if arch(x86_64)
        guard let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed)
        else { return nil }
        return url.deletingLastPathComponent().appendingPathComponent("appcast-x86_64.xml").absoluteString
        #else
        return nil
        #endif
    }
}
