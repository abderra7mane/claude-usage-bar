import AppKit
import ClaudeUsageCore
import UserNotifications

/// Notifies when an account's usage passes one of `UsageAlert.thresholds`.
@MainActor
final class UsageNotifier: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    /// `UNUserNotificationCenter` needs an app bundle, so it's unavailable to `swift run`.
    let isAvailable = Bundle.main.bundleIdentifier != nil
    @Published private(set) var isDenied = false

    override init() {
        super.init()
        guard isAvailable else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        guard isAvailable else { return }
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            await refreshAuthorization()
        }
    }

    func refreshAuthorization() async {
        guard isAvailable else { return }
        isDenied = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    func usageChanged(for account: Account, showsAccountName: Bool, from previous: UsageReport, to current: UsageReport) {
        guard isAvailable else { return }
        let now = Date.now
        for (name, window) in [("Session", \UsageReport.fiveHour), ("Weekly", \UsageReport.sevenDay)] {
            guard let old = previous[keyPath: window],
                  let new = current[keyPath: window],
                  let threshold = UsageAlert.threshold(crossedFrom: old.effectiveUtilization(at: now), to: new.utilization)
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = threshold >= UsageLevel.criticalThreshold
                ? "\(name) limit reached"
                : "\(name) usage at \(UsageFormat.percent(new.utilization))"
            if showsAccountName {
                content.subtitle = account.name
            }
            content.body = UsageFormat.reset(new.resetsAt, now: now)
            content.sound = .default
            let request = UNNotificationRequest(identifier: "\(account.id)-\(name)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
