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
        connect()
        fetchClaudeUsage()
        startPollingLoop()
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

    private func fetchQuota() {
        Task {
            let service = UsagePollingService(rpcClient: serverManager.rpcClient)
            do {
                let response = try await service.fetchRateLimits()
                usage = .from(response, lastUpdated: Date(), connectionStatus: .connected)
            } catch {
                usage.connectionStatus = .error(error.localizedDescription)
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
