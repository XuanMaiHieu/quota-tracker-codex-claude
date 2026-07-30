import os

enum Logger {
    private static let osLog = os.Logger(subsystem: "dev.hieumike.codexmeter", category: "app")
    static var isEnabled = true

    static func log(_ message: String) {
        guard isEnabled else { return }
        osLog.debug("\(message, privacy: .public)")
    }
}
