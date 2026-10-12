import AppKit

@main
@MainActor
enum ClaudeUsageBarApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel(settings: AppSettings())
    private let updater = Updater()
    private lazy var settingsWindow = SettingsWindowController(model: model, updater: updater)
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(model: model, updater: updater) { [weak self] in
            self?.settingsWindow.show()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.refreshAll() }
        }
    }
}
