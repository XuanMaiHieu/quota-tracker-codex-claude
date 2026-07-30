import Foundation

enum DisplayMode: String, CaseIterable, Identifiable {
    case minimal
    case useful
    case compact

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minimal: return "Minimal (C 24%)"
        case .useful: return "Useful (5H 24%  W 61%)"
        case .compact: return "Compact (⌁ 24% / 61%)"
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
