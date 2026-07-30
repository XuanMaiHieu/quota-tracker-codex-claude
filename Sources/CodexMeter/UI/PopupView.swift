import SwiftUI

struct PopupView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Codex Meter")
                    .font(.headline)
                Spacer()
                StatusBadgeView(status: appState.usage.connectionStatus)
            }

            Divider()

            UsageRowView(title: "5-hour usage", window: appState.usage.primary, resetLabel: "Resets in")
            UsageRowView(title: "Weekly usage", window: appState.usage.secondary, resetLabel: "Resets on")

            if let lastUpdated = appState.usage.lastUpdated {
                Text("Last updated \(lastUpdated.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button("Refresh") { appState.refresh() }
                Button("Settings") { SettingsWindowController.shared.show(settings: settings) }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
