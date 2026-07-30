import SwiftUI

enum UsageColor {
    static func forPercent(_ percent: Double?) -> Color {
        guard let percent else { return .secondary }
        if percent >= 85 { return Color(red: 1.0, green: 0.36, blue: 0.36) }
        if percent >= 60 { return Color(red: 1.0, green: 0.72, blue: 0.3) }
        return Color(red: 0.4, green: 0.78, blue: 1.0)
    }
}
