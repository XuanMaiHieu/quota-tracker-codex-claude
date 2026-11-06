import SwiftUI

/// Popup section body for Antigravity: one compact block per account (live account first),
/// one row per quota group with 5H / W mini bars, plus blocked-group warnings.
struct AgyAccountsView: View {
    let state: AgyState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(state.blocked, id: \.group) { item in
                Label("\(item.group.label): every account is out of quota · back in \(CountdownFormatter.resetsIn(item.until))",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let error = state.accountsError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            ForEach(state.accounts) { account in
                AgyAccountBlock(account: account)
            }
            if state.lastUpdated != nil {
                Text("Queue \(state.running)/\(state.maxConcurrency) running · \(state.queued) waiting · \(state.switches) account switches")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AgyAccountBlock: View {
    let account: AgyAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(account.name).font(.subheadline).bold()
                if account.isActive {
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.green, in: Capsule())
                }
                Spacer()
                if let email = account.email, email != account.name {
                    Text(email)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            ForEach(account.groups) { usage in
                AgyGroupRow(usage: usage)
            }
        }
    }
}

private struct AgyGroupRow: View {
    let usage: AgyGroupUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Text(usage.group.label)
                    .font(.caption)
                    .foregroundStyle(usage.available ? .primary : Color.red)
                    .frame(width: 66, alignment: .leading)
                MiniMeter(label: "5H", window: usage.fiveHour)
                MiniMeter(label: "W", window: usage.weekly)
            }
            if let resets = resetText {
                Text(resets)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 72)
            }
        }
    }

    private var resetText: String? {
        var parts: [String] = []
        if let five = usage.fiveHour, five.resetsAt != nil {
            parts.append("5H \(CountdownFormatter.resetsIn(five.resetsAt)) (\(CountdownFormatter.resetsAtClockTime(five.resetsAt)))")
        }
        if let weekly = usage.weekly, weekly.resetsAt != nil {
            parts.append("W \(CountdownFormatter.resetsOn(weekly.resetsAt))")
        }
        return parts.isEmpty ? nil : "resets " + parts.joined(separator: " · ")
    }
}

private struct MiniMeter: View {
    let label: String
    let window: UsageWindow?

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: 16, alignment: .leading)
            if let window {
                ProgressView(value: window.usedPercent, total: 100)
                    .tint(UsageColor.forPercent(window.usedPercent))
                    .frame(width: 38)
                Text("\(Int(window.usedPercent.rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(UsageColor.forPercent(window.usedPercent))
                    .frame(width: 32, alignment: .trailing)
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 73, alignment: .leading)
            }
        }
    }
}
