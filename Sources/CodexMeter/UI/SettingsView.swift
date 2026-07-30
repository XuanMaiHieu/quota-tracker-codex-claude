import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        TabView {
            generalTab.tabItem { Text("General") }
            displayTab.tabItem { Text("Display") }
            dataTab.tabItem { Text("Data") }
        }
        .padding(20)
        .frame(width: 380, height: 200)
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
