import Combine
import Foundation
import Sparkle

/// Checks the GitHub releases appcast for updates. Disabled in builds without an update signing key.
@MainActor
final class Updater: ObservableObject {
    let isEnabled = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") != nil
    @Published private(set) var canCheckForUpdates = false

    private let controller = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set {
            objectWillChange.send()
            controller.updater.automaticallyChecksForUpdates = newValue
        }
    }

    init() {
        guard isEnabled else { return }
        controller.startUpdater()
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
