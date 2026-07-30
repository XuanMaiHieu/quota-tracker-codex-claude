import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var usage: UsageState = .dummy

    let serverManager = CodexServerManager()
    /// Fallback polling interval; overridden by SettingsStore in M5.
    var refreshIntervalSeconds: Double = 30
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
        startPollingLoop()
    }

    /// Ties the fallback polling interval to Settings' Data tab.
    func bind(to settings: SettingsStore) {
        settings.$refreshInterval
            .sink { [weak self] interval in
                self?.refreshIntervalSeconds = Double(interval.rawValue)
                self?.startPollingLoop()
            }
            .store(in: &cancellables)
    }

    /// Connects to the real `codex app-server`; a successful handshake triggers
    /// an initial quota fetch (see the `connectionStatus` sink above).
    func connect() {
        Task { await serverManager.start() }
    }

    func refresh() {
        if usage.connectionStatus == .connected {
            fetchQuota()
        } else {
            connect()
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
                if self.usage.connectionStatus == .connected {
                    self.fetchQuota()
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
}
