import SwiftUI

@main
struct CodexMeterApp: App {
    @StateObject private var appState: AppState
    @StateObject private var settings: SettingsStore

    init() {
        let appState = AppState()
        let settings = SettingsStore()
        appState.bind(to: settings)
        _appState = StateObject(wrappedValue: appState)
        _settings = StateObject(wrappedValue: settings)
    }

    var body: some Scene {
        MenuBarExtra {
            PopupView()
                .environmentObject(appState)
                .environmentObject(settings)
        } label: {
            MenuBarLabel(appState: appState, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }
}
