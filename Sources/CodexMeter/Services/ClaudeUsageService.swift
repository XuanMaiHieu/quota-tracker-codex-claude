import Foundation
import Security

enum ClaudeUsageError: LocalizedError {
    case missingCredentials
    case keychainAccessDenied
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "not logged in"
        case .keychainAccessDenied: return "Keychain access needed – click Refresh and choose Always Allow"
        case .requestFailed(let code): return "HTTP \(code)"
        }
    }
}

/// Reads Claude Code's own OAuth token and calls the same usage endpoint the
/// CLI uses for its own quota display. No RPC/process involved, unlike Codex.
struct ClaudeUsageService {
    func fetchUsage() async throws -> ClaudeUsageResponseWire {
        let token = try Self.resolveAccessToken()

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/oauth/usage")!)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        request.setValue("codex-meter/1.0", forHTTPHeaderField: "user-agent")
        request.timeoutInterval = 5

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ClaudeUsageError.requestFailed(code)
        }
        return try JSONDecoder().decode(ClaudeUsageResponseWire.self, from: data)
    }

    /// Claude Code stores its OAuth token in the macOS Keychain under this
    /// service name; `~/.claude/.credentials.json` is a fallback for setups
    /// where the CLI was configured to use a plain file instead.
    /// The macOS Keychain prompts for the user's password whenever this app
    /// isn't (yet, or anymore) on the item's trusted-app list — e.g. right
    /// after `claude` in Terminal rewrites the credential on token refresh.
    /// That's an OS-enforced security boundary, not something we can bypass
    /// silently; distinguish "denied/needs a prompt" from "no item at all"
    /// so the UI can tell the user what to do (click Refresh, choose Always
    /// Allow) instead of misleadingly claiming they're logged out.
    private static func resolveAccessToken() throws -> String {
        switch readFromKeychain() {
        case .success(let token):
            return token
        case .failure(let error):
            if let fileToken = readFromCredentialsFile() {
                return fileToken
            }
            throw error
        }
    }

    private static func readFromKeychain() -> Result<String, ClaudeUsageError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let token = parseAccessToken(from: data) else {
                return .failure(.missingCredentials)
            }
            return .success(token)
        case errSecItemNotFound:
            return .failure(.missingCredentials)
        default:
            // errSecUserCanceled, errSecAuthFailed, errSecInteractionNotAllowed, etc.
            return .failure(.keychainAccessDenied)
        }
    }

    private static func readFromCredentialsFile() -> String? {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".claude/.credentials.json")
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return parseAccessToken(from: data)
    }

    private static func parseAccessToken(from data: Data) -> String? {
        struct Wrapper: Decodable {
            struct OAuth: Decodable { let accessToken: String }
            let claudeAiOauth: OAuth
        }
        return try? JSONDecoder().decode(Wrapper.self, from: data).claudeAiOauth.accessToken
    }
}
