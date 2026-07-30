import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var appState: AppState
    let displayMode: DisplayMode

    var body: some View {
        Text(labelText)
    }

    private var labelText: String {
        let usage = appState.usage
        if case .error = usage.connectionStatus {
            return "Codex ⚠︎"
        }
        switch displayMode {
        case .minimal:
            let percent = usage.primary?.usedPercent ?? usage.secondary?.usedPercent
            return percent.map { "C \(Int($0))%" } ?? "C --"
        case .useful:
            let primary = usage.primary.map { "5H \(Int($0.usedPercent))%" } ?? "5H --"
            let secondary = usage.secondary.map { "W \(Int($0.usedPercent))%" } ?? "W --"
            return "\(primary)  \(secondary)"
        case .compact:
            let primary = usage.primary.map { "\(Int($0.usedPercent))" } ?? "--"
            let secondary = usage.secondary.map { "\(Int($0.usedPercent))" } ?? "--"
            return "⌁ \(primary)% / \(secondary)%"
        }
    }
}
