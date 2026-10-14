import Combine
import Foundation
import Sparkle

/// Checks the GitHub releases appcast for updates. Disabled in builds without an update signing key.
@MainActor
final class Updater: ObservableObject {
    let isEnabled = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") != nil
    @Published private(set) var canCheckForUpdates = false
    /// A check found an update the user hasn't installed or skipped yet.
    @Published private(set) var updateAvailable = false

    private let events = UpdaterEvents()
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
            updaterDelegate: events,
            userDriverDelegate: reminder
        )
        events.onChange = { [weak self] in self?.updateAvailable = $0 }
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
    ) {}
}

/// Tracks whether an update is available: dismissing it keeps the indicator, installing or skipping it clears it.
@MainActor
private final class UpdaterEvents: NSObject, SPUUpdaterDelegate {
    var onChange: ((Bool) -> Void)?

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        onChange?(true)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        onChange?(false)
    }

    func updater(
        _ updater: SPUUpdater,
        userDidMake choice: SPUUserUpdateChoice,
        forUpdate updateItem: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        if choice != .dismiss {
            onChange?(false)
        }
    }

    /// Apple Silicon reads `SUFeedURL`; Intel reads its own appcast next to it. A universal build follows the
    /// architecture it runs as, so it updates to that architecture's build.
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
