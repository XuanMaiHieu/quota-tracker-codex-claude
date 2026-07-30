import SwiftUI

struct UsageRowView: View {
    let title: String
    let window: UsageWindow?
    let resetLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(percentText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(color)
            }
            ProgressView(value: window?.usedPercent ?? 0, total: 100)
                .tint(color)
            HStack {
                Text(resetLabel)
                Spacer()
                Text(resetText)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var percentText: String {
        guard let window else { return "N/A" }
        let used = Int(window.usedPercent)
        let remaining = 100 - used
        return "\(used)% used · \(remaining)% left"
    }

    private var color: Color {
        guard let percent = window?.usedPercent else { return .secondary }
        if percent >= 85 { return .red }
        if percent >= 60 { return .yellow }
        return .green
    }

    private var resetText: String {
        guard let window else { return "N/A" }
        switch window.kind {
        case .weekly:
            return CountdownFormatter.resetsOn(window.resetsAt)
        default:
            return CountdownFormatter.resetsIn(window.resetsAt)
        }
    }
}
