import SwiftUI
import AppKit

struct MenuBarLabel: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settings: SettingsStore

    var body: some View {
        if let image = renderedImage {
            Image(nsImage: image)
        } else {
            Text(fallbackText)
        }
    }

    private static let codexColor = Color(red: 0x25 / 255.0, green: 0x96 / 255.0, blue: 0xBE / 255.0)
    private static let claudeColor = Color(red: 0xC1 / 255.0, green: 0x5F / 255.0, blue: 0x3C / 255.0)

    private var fallbackText: String {
        if !settings.showCodex && !settings.showClaude { return "Quota off" }
        return "Quota ⚠︎"
    }

    private func metric(_ window: UsageWindow?) -> MenuBarBadgesView.Metric {
        guard let window else { return .init(text: "--", color: .white.opacity(0.5)) }
        return .init(text: "\(Int(window.usedPercent))%", color: UsageColor.forPercent(window.usedPercent))
    }

    private var providers: [MenuBarBadgesView.ProviderData] {
        var result: [MenuBarBadgesView.ProviderData] = []
        if settings.showCodex, !isError(appState.usage.connectionStatus) {
            result.append(.init(
                backgroundColor: Self.codexColor,
                fiveHour: metric(appState.usage.primary),
                weekly: metric(appState.usage.secondary)
            ))
        }
        if settings.showClaude, !isError(appState.claudeUsage.connectionStatus) {
            result.append(.init(
                backgroundColor: Self.claudeColor,
                fiveHour: metric(appState.claudeUsage.primary),
                weekly: metric(appState.claudeUsage.secondary)
            ))
        }
        return result
    }

    private var renderedImage: NSImage? {
        let providers = self.providers
        guard !providers.isEmpty else { return nil }
        let renderer = ImageRenderer(content: MenuBarBadgesView(providers: providers))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        return renderer.nsImage
    }

    private func isError(_ status: ConnectionStatus) -> Bool {
        if case .error = status { return true }
        return false
    }
}
