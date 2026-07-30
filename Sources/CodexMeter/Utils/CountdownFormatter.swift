import Foundation

enum CountdownFormatter {
    static func resetsIn(_ date: Date?, from now: Date = Date()) -> String {
        guard let date else { return "N/A" }
        let seconds = Int(date.timeIntervalSince(now))
        guard seconds > 0 else { return "now" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours >= 24 {
            let days = hours / 24
            return "\(days)d \(hours % 24)h"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    static func resetsOn(_ date: Date?) -> String {
        guard let date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE HH:mm"
        return formatter.string(from: date)
    }
}
