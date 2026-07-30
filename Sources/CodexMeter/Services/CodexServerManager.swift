import Foundation

/// Owns the `codex app-server` subprocess lifecycle: spawning, stdin/stdout pipes,
/// the initialize handshake, and exposing connection state to the rest of the app.
@MainActor
final class CodexServerManager: ObservableObject {
    @Published private(set) var connectionStatus: ConnectionStatus = .connecting

    let rpcClient = CodexRPCClient()

    private var process: Process?
    private var stdinHandle: FileHandle?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var isStoppedIntentionally = false

    /// plan.md §11: 2s, 5s, 10s, capped at 60s.
    private static let backoffSteps: [Double] = [2, 5, 10, 20, 40, 60]

    func start() async {
        guard process == nil else { return }
        isStoppedIntentionally = false
        connectionStatus = .connecting

        guard let executablePath = Self.resolveCodexPath() else {
            connectionStatus = .error("codex CLI not found in PATH")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["app-server", "--listen", "stdio://"]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        self.process = process
        self.stdinHandle = stdinPipe.fileHandleForWriting

        await rpcClient.attachWriter { [weak self] data in
            self?.stdinHandle?.write(data)
        }

        // Wire the stdout reader before writing anything so we never miss the
        // `initialize` response (and to avoid the classic Process/Pipe deadlock).
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            guard let rpcClient = self?.rpcClient else { return }
            Task { await rpcClient.handleIncoming(data) }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Logger.log("codex app-server stderr: \(text)")
        }

        process.terminationHandler = { [weak self] terminated in
            let status = terminated.terminationStatus
            Task { @MainActor [weak self] in
                self?.handleTermination(status: status)
            }
        }

        do {
            try process.run()
        } catch {
            connectionStatus = .error("Failed to launch codex: \(error.localizedDescription)")
            self.process = nil
            return
        }

        do {
            try await performHandshake()
            connectionStatus = .connected
            reconnectAttempt = 0
        } catch {
            connectionStatus = .error(error.localizedDescription)
        }
    }

    func stop() {
        isStoppedIntentionally = true
        reconnectTask?.cancel()
        reconnectTask = nil
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
        stdinHandle = nil
    }

    private func performHandshake() async throws {
        struct ClientInfo: Encodable {
            let name = "CodexMeter"
            let title = "Codex Meter"
            let version = "0.1.0"
        }
        struct InitializeParams: Encodable {
            let clientInfo: ClientInfo
        }
        struct InitializeResult: Decodable {
            let userAgent: String?
        }
        _ = try await rpcClient.call(
            method: "initialize",
            params: InitializeParams(clientInfo: ClientInfo()),
            as: InitializeResult.self
        )
        try await rpcClient.notify(method: "initialized", params: EmptyParams())
    }

    private func handleTermination(status: Int32) {
        guard process != nil else { return } // already stopped intentionally
        connectionStatus = .error("codex app-server exited (code \(status))")
        let client = rpcClient
        Task { await client.failAllPending(with: RPCError.processExited(status)) }
        process = nil
        guard !isStoppedIntentionally else { return }
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        let delay = Self.backoffSteps[min(reconnectAttempt, Self.backoffSteps.count - 1)]
        reconnectAttempt += 1
        Logger.log("Reconnecting to codex app-server in \(delay)s (attempt \(reconnectAttempt))")
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            await self.start()
        }
    }

    /// Looks up `codex` on PATH rather than hardcoding a Homebrew-specific path.
    /// GUI-launched apps (Finder double-click, or a login item at boot) get a
    /// minimal system PATH that does NOT include Homebrew/nvm/etc — the process's
    /// own PATH alone is not enough, so common install dirs and a login-shell
    /// lookup are tried as fallbacks.
    private static func resolveCodexPath() -> String? {
        let fileManager = FileManager.default
        let envPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        var searchDirs = envPath.split(separator: ":").map(String.init)
        searchDirs.append(contentsOf: [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            NSHomeDirectory() + "/.local/bin"
        ])
        for dir in searchDirs {
            let candidate = (dir as NSString).appendingPathComponent("codex")
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return resolveViaLoginShell()
    }

    /// Runs the user's login shell to pick up PATH entries added by shell
    /// profiles (nvm, custom installers, etc) that a bare GUI process misses.
    private static func resolveViaLoginShell() -> String? {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-lc", "command -v codex"]
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        guard let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty,
              FileManager.default.isExecutableFile(atPath: path) else {
            return nil
        }
        return path
    }
}
