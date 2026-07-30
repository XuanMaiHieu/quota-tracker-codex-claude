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
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(Self.percentTextColor)
                    .shadow(color: .black.opacity(0.35), radius: 1.5, x: 0, y: 1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black, in: Capsule())
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
        UsageColor.forPercent(window?.usedPercent)
    }

    private static let percentTextColor = Color(red: 0.36, green: 0.82, blue: 0.44)

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
