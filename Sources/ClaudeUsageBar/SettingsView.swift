import AppKit
import ClaudeUsageCore
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(model: model, settings: model.settings))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Claude Usage Bar Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        let suggestions = settings.suggestedFolders

        Form {
            Section {
                if settings.accounts.isEmpty {
                    Text("No accounts yet.").foregroundStyle(.secondary)
                }
                ForEach($settings.accounts) { $account in
                    AccountRow(
                        account: $account,
                        monitor: model.monitor(for: account),
                        onRemove: { settings.removeAccount(id: account.id) }
                    )
                }
            } header: {
                Text("Accounts")
            } footer: {
                HStack {
                    Text("Each account is a Claude Code config folder (`CLAUDE_CONFIG_DIR`).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Add Folder…", action: chooseFolder)
                }
            }

            if !suggestions.isEmpty {
                Section("Detected folders") {
                    ForEach(suggestions, id: \.self) { url in
                        HStack {
                            Text(ConfigDirectory.displayPath(url))
                            Spacer()
                            Button("Add") { settings.addAccount(at: url) }
                        }
                    }
                }
            }

            Section("Menu bar") {
                Toggle("Show account names", isOn: $settings.showAccountNames)
                Toggle("Show percentages", isOn: $settings.showPercentages)
            }

            Section("General") {
                Picker("Refresh every", selection: $settings.refreshInterval) {
                    ForEach(AppSettings.refreshIntervalOptions, id: \.self) { interval in
                        Text("\(Int(interval / 60)) min").tag(interval)
                    }
                }
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                if let error = settings.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 540)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.showsHiddenFiles = true
        panel.directoryURL = ConfigDirectory.home
        panel.prompt = "Add"
        panel.message = "Choose Claude Code config folders, such as ~/.claude"
        NSApp.activate()
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach(settings.addAccount(at:))
    }
}

private struct AccountRow: View {
    @Binding var account: Account
    let monitor: UsageMonitor?
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Name", text: $account.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
                Text(ConfigDirectory.displayPath(account.url))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Toggle("Menu bar", isOn: $account.showInMenuBar)
                    .toggleStyle(.checkbox)
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove account")
            }
            if let monitor {
                AccountStatus(monitor: monitor, configDirectory: account.url)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct AccountStatus: View {
    @ObservedObject var monitor: UsageMonitor
    let configDirectory: URL

    var body: some View {
        if let problem = monitor.problem {
            ProblemView(problem: problem, configDirectory: configDirectory)
        } else if monitor.report != nil {
            Label(
                monitor.plan.map { "Logged in · \($0.capitalized)" } ?? "Logged in",
                systemImage: "checkmark.circle.fill"
            )
            .font(.caption)
            .foregroundStyle(.green)
        } else {
            Label("Checking…", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
