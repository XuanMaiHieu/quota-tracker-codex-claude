import SwiftUI

struct PopupView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Codex Meter")
                .font(.headline)

            if settings.showCodex {
                Divider()

                HStack {
                    AppLogo.image(named: "codex-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text("Codex").font(.subheadline).bold()
                    Spacer()
                    StatusBadgeView(status: appState.usage.connectionStatus)
                }
                UsageRowView(title: "5-hour usage", window: appState.usage.primary, resetLabel: "Resets in")
                UsageRowView(title: "Weekly usage", window: appState.usage.secondary, resetLabel: "Resets on")
                if let lastUpdated = appState.usage.lastUpdated {
                    Text("Last updated \(lastUpdated.formatted(date: .omitted, time: .standard))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if settings.showClaude {
                Divider()

                HStack {
                    AppLogo.image(named: "claude-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text("Claude Code").font(.subheadline).bold()
                    Spacer()
                    StatusBadgeView(status: appState.claudeUsage.connectionStatus)
                }
                UsageRowView(title: "5-hour usage", window: appState.claudeUsage.primary, resetLabel: "Resets in")
                UsageRowView(title: "7-day usage", window: appState.claudeUsage.secondary, resetLabel: "Resets on")
                if let lastUpdated = appState.claudeUsage.lastUpdated {
                    Text("Last updated \(lastUpdated.formatted(date: .omitted, time: .standard))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
        .frame(width: 300)
    }
}
