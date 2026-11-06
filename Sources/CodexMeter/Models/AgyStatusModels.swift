import Foundation

// MARK: - Wire types (server-agy-api `GET /dashboard/api/status`, read-only app token)

struct AgyWindowWire: Decodable {
    let remaining: Double?
    let resetAt: Double?

    enum CodingKeys: String, CodingKey {
        case remaining
        case resetAt = "reset_at"
    }
}

struct AgyGroupWire: Decodable {
    let available: Bool
    let remaining: Double?
    /// Keyed by window: "5h", "weekly".
    let windows: [String: AgyWindowWire]?
}

struct AgyAccountWire: Decodable {
    let id: String
    let alias: String?
    let email: String?
    let active: Bool
    /// Keyed by quota group: "gemini", "thirdparty" (Claude/GPT), "argon".
    let groups: [String: AgyGroupWire]
}

struct AgyBlockedWire: Decodable {
    let resetAt: Double?

    enum CodingKeys: String, CodingKey {
        case resetAt = "reset_at"
    }
}

struct AgyRotationWire: Decodable {
    let enabled: Bool
    let account: String?
    let switches: Int
    let blocked: [String: AgyBlockedWire]?
    let lastError: String?

    enum CodingKeys: String, CodingKey {
        case enabled, account, switches, blocked
        case lastError = "last_error"
    }
}

struct AgyQueueWire: Decodable {
    let running: Int
    let queued: Int
    let maxConcurrency: Int
}

struct AgyStatusWire: Decodable {
    let rotation: AgyRotationWire
    let queue: AgyQueueWire
    let accounts: [AgyAccountWire]?
    let accountsError: String?

    enum CodingKeys: String, CodingKey {
        case rotation, queue, accounts
        case accountsError = "accounts_error"
    }
}

// MARK: - UI-facing types

enum AgyGroup: String, CaseIterable, Identifiable {
    case gemini
    case thirdparty
    case argon

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gemini: return "Gemini"
        case .thirdparty: return "Claude/GPT"
        case .argon: return "Argon"
        }
    }
}

struct AgyGroupUsage: Identifiable {
    let group: AgyGroup
    let available: Bool
    let fiveHour: UsageWindow?
    let weekly: UsageWindow?

    var id: AgyGroup { group }
}

struct AgyAccount: Identifiable {
    let id: String
    let name: String
    let email: String?
    let isActive: Bool
    let groups: [AgyGroupUsage]
}

struct AgyState {
    var accounts: [AgyAccount] = []
    var activeName: String?
    var switches = 0
    /// Groups where every account is out of quota, with when the first one refills.
    var blocked: [(group: AgyGroup, until: Date?)] = []
    var running = 0
    var queued = 0
    var maxConcurrency = 0
    var accountsError: String?
    var lastUpdated: Date?
    var connectionStatus: ConnectionStatus = .connecting

    var activeAccount: AgyAccount? { accounts.first { $0.isActive } }

    /// The live account's 5h / weekly windows for the menu bar: one group, or for `.mostUsed`
    /// whichever group is closest to its limit in each window (the one that triggers a switch).
    func badge(for choice: AgyBadgeGroup) -> (fiveHour: UsageWindow?, weekly: UsageWindow?) {
        guard let account = activeAccount else { return (nil, nil) }
        if let group = choice.group {
            let usage = account.groups.first { $0.group == group }
            return (usage?.fiveHour, usage?.weekly)
        }
        let mostUsed = { (windows: [UsageWindow]) in windows.max { $0.usedPercent < $1.usedPercent } }
        return (mostUsed(account.groups.compactMap(\.fiveHour)), mostUsed(account.groups.compactMap(\.weekly)))
    }
}

// MARK: - Normalization (the server reports remaining fractions; this app shows used %)

extension UsageWindow {
    init?(agy wire: AgyWindowWire?, kind: UsageWindowKind) {
        guard let wire, let remaining = wire.remaining else { return nil }
        self.kind = kind
        usedPercent = max(0, min(100, (1 - remaining) * 100))
        resetsAt = wire.resetAt.map { Date(timeIntervalSince1970: $0) }
        durationMinutes = nil
    }
}

extension AgyState {
    static func from(_ wire: AgyStatusWire, lastUpdated: Date) -> AgyState {
        let accounts = (wire.accounts ?? [])
            .map { acct -> AgyAccount in
                let groups = AgyGroup.allCases.compactMap { group -> AgyGroupUsage? in
                    guard let g = acct.groups[group.rawValue] else { return nil }
                    return AgyGroupUsage(
                        group: group,
                        available: g.available,
                        fiveHour: UsageWindow(agy: g.windows?["5h"], kind: .fiveHour),
                        weekly: UsageWindow(agy: g.windows?["weekly"], kind: .weekly)
                    )
                }
                return AgyAccount(id: acct.id, name: acct.alias ?? acct.email ?? acct.id, email: acct.email, isActive: acct.active, groups: groups)
            }
            .sorted { ($0.isActive ? 0 : 1, $0.name) < ($1.isActive ? 0 : 1, $1.name) }
        let blocked = (wire.rotation.blocked ?? [:])
            .compactMap { key, value -> (group: AgyGroup, until: Date?)? in
                guard let group = AgyGroup(rawValue: key) else { return nil }
                return (group, value.resetAt.map { Date(timeIntervalSince1970: $0) })
            }
            .sorted { $0.group.rawValue < $1.group.rawValue }
        return AgyState(
            accounts: accounts,
            activeName: wire.rotation.account,
            switches: wire.rotation.switches,
            blocked: blocked,
            running: wire.queue.running,
            queued: wire.queue.queued,
            maxConcurrency: wire.queue.maxConcurrency,
            accountsError: wire.accountsError ?? wire.rotation.lastError.map { "agy-auth: \($0)" },
            lastUpdated: lastUpdated,
            connectionStatus: .connected
        )
    }
}
