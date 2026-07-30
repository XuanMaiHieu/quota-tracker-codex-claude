import AppKit
import SwiftUI

/// MenuBarExtra-only apps (no WindowGroup) don't reliably wire up SwiftUI's
/// `Settings` scene / `showSettingsWindow:` action, so we own a plain NSWindow
/// instead of depending on that mechanism.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(settings: SettingsStore) {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: settings))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Codex Meter Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
