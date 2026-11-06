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
    /// Read it through `/usr/bin/security` first, the same way the CLI does:
    /// that tool is on the item's trusted-app list, whereas this app's own
    /// "Always Allow" entry stops being honoured every time `claude` rewrites
    /// the item on token refresh, which re-prompted for the login password on
    /// every new session. The direct Keychain read stays as a fallback; when
    /// it's denied, distinguish that from "no item at all" so the UI doesn't
    /// misleadingly claim the user is logged out.
    private static func resolveAccessToken() throws -> String {
        if let token = readViaSecurityTool() {
            return token
        }
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

    private static func readViaSecurityTool() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return parseAccessToken(from: data)
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
