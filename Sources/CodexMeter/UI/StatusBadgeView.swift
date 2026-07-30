import SwiftUI

struct StatusBadgeView: View {
    let status: ConnectionStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var color: Color {
        switch status {
        case .connected: return .green
        case .connecting, .refreshing: return .yellow
        case .error: return .red
        }
    }

    private var label: String {
        switch status {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .refreshing: return "Refreshing"
        case .error(let message): return "Error: \(message)"
        }
    }
}
