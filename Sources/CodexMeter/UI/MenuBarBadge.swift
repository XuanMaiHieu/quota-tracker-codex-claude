import SwiftUI

private struct MetricStack: View {
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(alignment: .center, spacing: -2) {
            Text(label)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
                .tracking(0.3)
            Text(value)
                .font(.system(size: 13, weight: .regular).monospacedDigit())
                .foregroundColor(.white)
        }
        .frame(minWidth: 26)
    }
}

private struct ProviderBadge: View {
    let backgroundColor: Color
    let fiveHour: MenuBarBadgesView.Metric
    let weekly: MenuBarBadgesView.Metric

    var body: some View {
        HStack(spacing: 10) {
            MetricStack(label: "5H", value: fiveHour.text, valueColor: fiveHour.color)
            MetricStack(label: "W", value: weekly.text, valueColor: weekly.color)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(backgroundColor))
    }
}

/// Rendered offscreen via `ImageRenderer` into a single `NSImage` for the menu bar —
/// NSStatusItem labels don't reliably composite multi-part SwiftUI view trees with
/// custom backgrounds, but a single flattened image always renders correctly.
struct MenuBarBadgesView: View {
    struct Metric {
        let text: String
        let color: Color
    }

    struct ProviderData {
        let backgroundColor: Color
        let fiveHour: Metric
        let weekly: Metric
    }

    let providers: [ProviderData]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(providers.enumerated()), id: \.offset) { _, provider in
                ProviderBadge(backgroundColor: provider.backgroundColor, fiveHour: provider.fiveHour, weekly: provider.weekly)
            }
        }
        .fixedSize()
    }
}
