import Foundation
import Security

enum AgyStatusError: LocalizedError {
    case notConfigured
    case badURL
    case unauthorized
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "not set up – Settings › Antigravity"
        case .badURL: return "invalid server URL"
        case .unauthorized: return "token rejected – make a new one in the dashboard"
        case .requestFailed(let code): return "HTTP \(code)"
        }
    }
}

/// Reads quota of every Antigravity (agy) account from a server-agy-api instance:
/// `GET <server>/dashboard/api/status` with a read-only dashboard app token.
struct AgyStatusService {
    let baseURL: String
    let token: String

    func fetchStatus() async throws -> AgyStatusWire {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed), components.scheme != nil, components.host != nil else {
            throw AgyStatusError.badURL
        }
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = basePath + "/dashboard/api/status"
        guard let url = components.url else { throw AgyStatusError.badURL }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        request.setValue("codex-meter/1.0", forHTTPHeaderField: "user-agent")
        // The server may ask Google for every account's quota on a cache miss (a few seconds).
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        if code == 401 { throw AgyStatusError.unauthorized }
        guard (200..<300).contains(code) else { throw AgyStatusError.requestFailed(code) }
        return try JSONDecoder().decode(AgyStatusWire.self, from: data)
    }
}

/// The dashboard token lives in this app's own Keychain item (created by the app, so reading
/// it back needs no prompt as long as the app keeps its stable signing identity).
/// `CODEXMETER_AGY_TOKEN` in the environment overrides it, for development runs.
enum AgyTokenStore {
    private static let service = "dev.hieumike.codexmeter.agy-dashboard"
    private static let account = "app-token"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func read() -> String? {
        if let env = ProcessInfo.processInfo.environment["CODEXMETER_AGY_TOKEN"], !env.isEmpty {
            return env
        }
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
    }

    @discardableResult
    static func save(_ token: String) -> Bool {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let data = value.data(using: .utf8) else { return false }
        SecItemDelete(baseQuery as CFDictionary)
        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrLabel as String] = "Codex Meter – agy dashboard token"
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess { Logger.log("AgyTokenStore.save failed: \(status)") }
        return status == errSecSuccess
    }

    static func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
