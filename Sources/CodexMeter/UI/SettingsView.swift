import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var agyTokenInput = ""
    @State private var agyTokenMessage = ""

    var body: some View {
        TabView {
            generalTab.tabItem { Text("General") }
            displayTab.tabItem { Text("Display") }
            dataTab.tabItem { Text("Data") }
            agyTab.tabItem { Text("Antigravity") }
        }
        .padding(20)
        .frame(width: 460, height: 330)
    }

    private var generalTab: some View {
        Form {
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
        }
    }

    private var displayTab: some View {
        Form {
            Picker("Menu bar mode", selection: $settings.displayMode) {
                ForEach(DisplayMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)

            Toggle("Show Codex", isOn: $settings.showCodex)
            Toggle("Show Claude Code", isOn: $settings.showClaude)
            Toggle("Show Antigravity", isOn: $settings.showAgy)
        }
    }

    /// server-agy-api quota: URL + the dashboard's read-only app token (kept in the Keychain).
    private var agyTab: some View {
        Form {
            Toggle("Show Antigravity (server-agy-api)", isOn: $settings.showAgy)
            TextField("Server URL", text: $settings.agyBaseURL, prompt: Text("http://117.7.0.31:4082"))
            SecureField("App token", text: $agyTokenInput, prompt: Text(settings.hasAgyToken ? "saved in Keychain – paste to replace" : "paste token"))
            HStack {
                Button("Save token") {
                    agyTokenMessage = settings.saveAgyToken(agyTokenInput) ? "Saved to Keychain" : "Could not save"
                    agyTokenInput = ""
                }
                .disabled(agyTokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Remove") {
                    settings.clearAgyToken()
                    agyTokenMessage = "Removed"
                }
                .disabled(!settings.hasAgyToken)
                Text(agyTokenMessage.isEmpty ? (settings.hasAgyToken ? "Token saved" : "No token") : agyTokenMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Picker("Menu bar badge", selection: $settings.agyBadgeGroup) {
                ForEach(AgyBadgeGroup.allCases) { group in
                    Text(group.label).tag(group)
                }
            }
            Text("Token: open <server>/dashboard, sign in, click \"Token cho app\", Copy. Read-only: it cannot run prompts.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dataTab: some View {
        Form {
            Picker("Refresh interval", selection: $settings.refreshInterval) {
                ForEach(RefreshInterval.allCases) { interval in
                    Text(interval.label).tag(interval)
                }
            }
            .pickerStyle(.radioGroup)
        }
    }
}
