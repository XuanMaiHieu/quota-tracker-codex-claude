import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var usage: UsageState = .notConnected
    @Published var claudeUsage: UsageState = .notConnected

    let serverManager = CodexServerManager()
    private let claudeUsageService = ClaudeUsageService()
    /// Fallback polling interval; overridden by SettingsStore in M5.
    var refreshIntervalSeconds: Double = 30
    private var showCodex = true
    private var showClaude = true
    private var cancellables: Set<AnyCancellable> = []
    private var pollingTask: Task<Void, Never>?

    /// How long after boot the OS/network needs to fully settle before it's worth
    /// even trying — a login item can be launched by macOS well before Wi-Fi and
    /// background services are back up, so retries alone weren't enough right after
    /// a restart.
    private static let bootGracePeriodSeconds: Double = 300

    init() {
        serverManager.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                self.usage.connectionStatus = status
                if status == .connected {
                    self.fetchQuota()
                }
            }
            .store(in: &cancellables)

        let bootDelay = Self.remainingBootGraceSeconds()
        if bootDelay > 0 {
            Logger.log("Delaying startup by \(Int(bootDelay))s to let the OS finish booting")
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(bootDelay))
                guard let self else { return }
                self.connect()
                self.fetchClaudeUsage()
                self.startPollingLoop()
            }
        } else {
            connect()
            fetchClaudeUsage()
            startPollingLoop()
        }
    }

    /// `systemUptime` already accounts for time spent before login, so a login-item
    /// launch right after a restart reports a small uptime; a manual launch later in
    /// the day reports an uptime well past the grace period and isn't delayed at all.
    private static func remainingBootGraceSeconds() -> Double {
        max(0, bootGracePeriodSeconds - ProcessInfo.processInfo.systemUptime)
    }

    /// Ties the fallback polling interval and per-provider on/off toggles to Settings.
    func bind(to settings: SettingsStore) {
        settings.$refreshInterval
            .sink { [weak self] interval in
                self?.refreshIntervalSeconds = Double(interval.rawValue)
                self?.startPollingLoop()
            }
            .store(in: &cancellables)

        settings.$showCodex
            .sink { [weak self] enabled in
                guard let self else { return }
                self.showCodex = enabled
                if enabled {
                    self.connect()
                } else {
                    self.serverManager.stop()
                    self.usage.connectionStatus = .connecting
                }
            }
            .store(in: &cancellables)

        settings.$showClaude
            .sink { [weak self] enabled in
                guard let self else { return }
                self.showClaude = enabled
                if enabled {
                    self.fetchClaudeUsage()
                } else {
                    self.claudeUsage.connectionStatus = .connecting
                }
            }
            .store(in: &cancellables)
    }

    /// Connects to the real `codex app-server`; a successful handshake triggers
    /// an initial quota fetch (see the `connectionStatus` sink above).
    func connect() {
        Task { await serverManager.start() }
    }

    func refresh() {
        if showCodex {
            if usage.connectionStatus == .connected {
                fetchQuota()
            } else {
                connect()
            }
        }
        if showClaude {
            fetchClaudeUsage()
        }
    }

    /// Continuous fallback polling (plan.md §7.3/§10): reconnect itself is handled
    /// by CodexServerManager's own backoff, this loop just re-fetches on a timer.
    private func startPollingLoop() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(for: .seconds(self.refreshIntervalSeconds))
                guard !Task.isCancelled else { return }
                if self.showCodex, self.usage.connectionStatus == .connected {
                    self.fetchQuota()
                }
                if self.showClaude {
                    self.fetchClaudeUsage()
                }
            }
        }
    }

    /// Retried with backoff before surfacing an error: right after a boot-time
    /// launch (login item), `codex app-server` can accept the RPC connection before
    /// the network/its own auth session has finished settling — Wi-Fi alone can take
    /// 10-30s to come back after a restart — so the first `account/rateLimits/read`
    /// calls can fail transiently even though the process is otherwise healthy and a
    /// later call succeeds once the system has caught up.
    private static let fetchQuotaBackoffSteps: [Double] = [2, 4, 8, 15, 30]

    private func fetchQuota(attempt: Int = 0) {
        Task {
            let service = UsagePollingService(rpcClient: serverManager.rpcClient)
            do {
                let response = try await service.fetchRateLimits()
                usage = .from(response, lastUpdated: Date(), connectionStatus: .connected)
            } catch {
                guard attempt < Self.fetchQuotaBackoffSteps.count else {
                    Logger.log("fetchQuota failed after retries: \(error)")
                    usage.connectionStatus = .error(error.localizedDescription)
                    return
                }
                let delay = Self.fetchQuotaBackoffSteps[attempt]
                Logger.log("fetchQuota failed (attempt \(attempt + 1)), retrying in \(delay)s: \(error)")
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                fetchQuota(attempt: attempt + 1)
            }
        }
    }

    /// Independent of the Codex process/RPC connection: this is a plain HTTPS
    /// call using Claude Code's own OAuth token, so it can succeed or fail on
    /// its own regardless of Codex's connection state.
    private func fetchClaudeUsage() {
        Task {
            do {
                let response = try await claudeUsageService.fetchUsage()
                claudeUsage = .from(claude: response, lastUpdated: Date(), connectionStatus: .connected)
            } catch {
                claudeUsage.connectionStatus = .error(error.localizedDescription)
            }
        }
    }
}
