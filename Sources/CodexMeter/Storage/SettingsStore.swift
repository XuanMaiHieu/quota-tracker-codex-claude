import Foundation
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
    @Published var displayMode: DisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: Keys.displayMode) }
    }
    @Published var refreshInterval: RefreshInterval {
        didSet { defaults.set(refreshInterval.rawValue, forKey: Keys.refreshInterval) }
    }
    /// Source of truth is `SMAppService.mainApp.status`, not the stored default,
    /// since the user can revoke login items from System Settings directly.
    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin(launchAtLogin) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let displayMode = "displayMode"
        static let refreshInterval = "refreshInterval"
        static let didBootstrapLaunchAtLogin = "didBootstrapLaunchAtLogin"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        displayMode = DisplayMode(rawValue: defaults.string(forKey: Keys.displayMode) ?? "") ?? .useful
        refreshInterval = RefreshInterval(rawValue: defaults.integer(forKey: Keys.refreshInterval)) ?? .thirty
        launchAtLogin = SMAppService.mainApp.status == .enabled

        // First run ever: enable "launch at login" automatically so a fresh
        // install starts working on boot without an extra manual step.
        if !defaults.bool(forKey: Keys.didBootstrapLaunchAtLogin) {
            defaults.set(true, forKey: Keys.didBootstrapLaunchAtLogin)
            if !launchAtLogin {
                launchAtLogin = true // triggers didSet -> applyLaunchAtLogin, self is fully initialized by now
            }
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            let isRegistered = SMAppService.mainApp.status == .enabled
            if enabled && !isRegistered {
                try SMAppService.mainApp.register()
            } else if !enabled && isRegistered {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.log("SMAppService toggle failed: \(error.localizedDescription)")
        }
    }
}
