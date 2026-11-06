import Foundation

enum DisplayMode: String, CaseIterable, Identifiable {
    case minimal
    case useful
    case compact

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minimal: return "Minimal (logo 24%)"
        case .useful: return "Useful (logo 5H 24% W 61%)"
        case .compact: return "Compact (logo 24%/61%)"
        }
    }
}

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case fifteen = 15
    case thirty = 30
    case sixty = 60

    var id: Int { rawValue }
    var label: String { "\(rawValue)s" }
}

/// Which quota group of the live Antigravity account the menu bar badge shows.
enum AgyBadgeGroup: String, CaseIterable, Identifiable {
    case mostUsed
    case gemini
    case thirdparty
    case argon

    var id: String { rawValue }

    var group: AgyGroup? { AgyGroup(rawValue: rawValue) }

    var label: String {
        switch self {
        case .mostUsed: return "Most used group"
        case .gemini: return "Gemini"
        case .thirdparty: return "Claude/GPT"
        case .argon: return "Gemini 4 Argon"
        }
    }
}
