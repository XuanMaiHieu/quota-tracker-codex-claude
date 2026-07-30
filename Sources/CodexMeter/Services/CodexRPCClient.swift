import Foundation

/// Speaks newline-delimited JSON-RPC 2.0 over stdio to `codex app-server`.
/// Owns request/response correlation by numeric id and republishes server-initiated
/// notifications as an AsyncStream.
actor CodexRPCClient {
    private var nextId = 1
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    private var lineBuffer = NDJSONLineBuffer()
    private var writeHandler: ((Data) -> Void)?

    private let notificationContinuation: AsyncStream<RPCNotification>.Continuation
    let notifications: AsyncStream<RPCNotification>

    init() {
        var continuation: AsyncStream<RPCNotification>.Continuation!
        self.notifications = AsyncStream { continuation = $0 }
        self.notificationContinuation = continuation
    }

    func attachWriter(_ writer: @escaping (Data) -> Void) {
        self.writeHandler = writer
    }

    func handleIncoming(_ chunk: Data) {
        for line in lineBuffer.append(chunk) where !line.isEmpty {
            handleLine(line)
        }
    }

    func call<Params: Encodable, Response: Decodable>(
        method: String,
        params: Params,
        as: Response.Type
    ) async throws -> Response {
        let id = nextId
        nextId += 1
        let request = JSONRPCRequestEnvelope(id: id, method: method, params: params)
        let payload = try JSONEncoder().encode(request)

        let raw: Data = try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            writeLine(payload)
        }

        let wrapper: RPCResultWrapper<Response>
        do {
            wrapper = try JSONDecoder().decode(RPCResultWrapper<Response>.self, from: raw)
        } catch {
            throw RPCError.decodingFailed(error.localizedDescription)
        }
        if let error = wrapper.error {
            throw RPCError.server(code: error.code, message: error.message)
        }
        guard let result = wrapper.result else {
            throw RPCError.missingResult
        }
        return result
    }

    func notify<Params: Encodable>(method: String, params: Params) throws {
        let notification = JSONRPCNotificationEnvelope(method: method, params: params)
        writeLine(try JSONEncoder().encode(notification))
    }

    /// Fails every in-flight request, e.g. when the subprocess dies.
    func failAllPending(with error: Error) {
        for (_, continuation) in pending {
            continuation.resume(throwing: error)
        }
        pending.removeAll()
    }

    private func handleLine(_ line: Data) {
        guard let peek = try? JSONDecoder().decode(RPCEnvelopePeek.self, from: line) else {
            Logger.log("Unparseable line from codex app-server: \(String(data: line, encoding: .utf8) ?? "<binary>")")
            return
        }
        if let id = peek.id, let continuation = pending.removeValue(forKey: id) {
            continuation.resume(returning: line)
        } else if let method = peek.method {
            notificationContinuation.yield(RPCNotification(method: method, raw: line))
        }
    }

    private func writeLine(_ data: Data) {
        guard let writer = writeHandler else { return }
        var payload = data
        payload.append(0x0A)
        writer(payload)
    }
}
