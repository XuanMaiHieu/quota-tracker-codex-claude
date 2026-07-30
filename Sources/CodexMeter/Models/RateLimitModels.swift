import Foundation

// MARK: - Wire types (verified against the real `codex app-server` v2 protocol)

struct RateLimitWindowWire: Decodable {
    let usedPercent: Int32
    let resetsAt: Int64?
    let windowDurationMins: Int64?
}

struct RateLimitCreditsWire: Decodable {
    let hasCredits: Bool
    let unlimited: Bool
    let balance: String? // verified: string, not a number
}

struct RateLimitSnapshotWire: Decodable {
    let limitId: String?
    let limitName: String?
    let planType: String?
    let primary: RateLimitWindowWire?
    let secondary: RateLimitWindowWire?
    let credits: RateLimitCreditsWire?
}

struct GetAccountRateLimitsResponse: Decodable {
    let rateLimits: RateLimitSnapshotWire
}

// MARK: - Normalized, UI-facing types

enum UsageWindowKind {
    case fiveHour
    case weekly
    case unknown
}

struct UsageWindow {
    let kind: UsageWindowKind
    let usedPercent: Double
    let resetsAt: Date?
    let durationMinutes: Int?
}

struct UsageState {
    var primary: UsageWindow?
    var secondary: UsageWindow?
    var lastUpdated: Date?
    var connectionStatus: ConnectionStatus

    static let notConnected = UsageState(primary: nil, secondary: nil, lastUpdated: nil, connectionStatus: .connecting)
}

// MARK: - Normalization

extension UsageWindow {
    /// Classifies by `windowDurationMins` rather than wire position: the live
    /// protocol was observed returning the weekly window in the `primary` slot
    /// with `secondary` nil, so "primary = 5h, secondary = weekly" cannot be assumed.
    init(wire: RateLimitWindowWire) {
        let minutes = wire.windowDurationMins.map(Int.init)
        switch minutes {
        case .some(let m) where m <= 360:
            kind = .fiveHour
        case .some(let m) where (9_000...11_000).contains(m):
            kind = .weekly
        default:
            kind = .unknown
        }
        usedPercent = Double(wire.usedPercent)
        resetsAt = wire.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        durationMinutes = minutes
    }
}

extension UsageState {
    static func from(_ response: GetAccountRateLimitsResponse, lastUpdated: Date, connectionStatus: ConnectionStatus) -> UsageState {
        let wireWindows = [response.rateLimits.primary, response.rateLimits.secondary].compactMap { $0 }
        let windows = wireWindows.map(UsageWindow.init(wire:))
        return UsageState(
            primary: windows.first { $0.kind == .fiveHour },
            secondary: windows.first { $0.kind == .weekly },
            lastUpdated: lastUpdated,
            connectionStatus: connectionStatus
        )
    }
}

extension UsageWindowKind: Equatable {}
