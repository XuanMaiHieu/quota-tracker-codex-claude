import Foundation

/// Fetches quota usage from `codex app-server` via the shared RPC client.
struct UsagePollingService {
    let rpcClient: CodexRPCClient

    func fetchRateLimits() async throws -> GetAccountRateLimitsResponse {
        try await rpcClient.call(
            method: "account/rateLimits/read",
            params: EmptyParams(),
            as: GetAccountRateLimitsResponse.self
        )
    }
}
