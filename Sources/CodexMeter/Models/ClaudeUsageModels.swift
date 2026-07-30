import Foundation

// MARK: - Wire types (verified against the real Claude Code `oauth/usage` endpoint)

struct ClaudeUsageWindowWire: Decodable {
    let utilization: Double?
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

struct ClaudeUsageResponseWire: Decodable {
    let fiveHour: ClaudeUsageWindowWire?
    let sevenDay: ClaudeUsageWindowWire?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

// MARK: - Normalization into the shared UsageWindow/UsageState UI types

private let claudeISOFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

extension UsageWindow {
    init?(claudeWire wire: ClaudeUsageWindowWire, kind: UsageWindowKind) {
        guard let utilization = wire.utilization else { return nil }
        self.kind = kind
        usedPercent = utilization
        resetsAt = wire.resetsAt.flatMap { claudeISOFormatter.date(from: $0) }
        durationMinutes = nil
    }
}

extension UsageState {
    static func from(claude wire: ClaudeUsageResponseWire, lastUpdated: Date, connectionStatus: ConnectionStatus) -> UsageState {
        UsageState(
            primary: wire.fiveHour.flatMap { UsageWindow(claudeWire: $0, kind: .fiveHour) },
            secondary: wire.sevenDay.flatMap { UsageWindow(claudeWire: $0, kind: .weekly) },
            lastUpdated: lastUpdated,
            connectionStatus: connectionStatus
        )
    }
}
