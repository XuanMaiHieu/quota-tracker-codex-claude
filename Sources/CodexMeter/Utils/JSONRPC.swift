import Foundation

struct EmptyParams: Codable {}

struct JSONRPCRequestEnvelope<Params: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: Int
    let method: String
    let params: Params
}

struct JSONRPCNotificationEnvelope<Params: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let method: String
    let params: Params
}

/// Minimal peek used only to route an inbound NDJSON line: a response carries `id`
/// (matches the id we sent in the originating request), a notification carries
/// `method` and no `id`.
struct RPCEnvelopePeek: Decodable {
    let id: Int?
    let method: String?
}

struct RPCJSONError: Decodable {
    let code: Int
    let message: String
}

struct RPCResultWrapper<T: Decodable>: Decodable {
    let result: T?
    let error: RPCJSONError?
}

struct RPCNotification {
    let method: String
    let raw: Data
}

enum RPCError: Error, LocalizedError {
    case server(code: Int, message: String)
    case missingResult
    case commandNotFound
    case launchFailed(String)
    case processExited(Int32)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .server(let code, let message):
            return "codex app-server error \(code): \(message)"
        case .missingResult:
            return "Missing result in codex app-server response"
        case .commandNotFound:
            return "codex CLI not found in PATH"
        case .launchFailed(let reason):
            return "Failed to launch codex app-server: \(reason)"
        case .processExited(let code):
            return "codex app-server exited (code \(code))"
        case .decodingFailed(let reason):
            return "Failed to decode codex app-server response: \(reason)"
        }
    }
}

/// Splits a byte stream into newline-delimited JSON lines. `codex app-server` frames
/// each JSON-RPC message as one compact JSON object per line (verified against the
/// live binary) rather than Content-Length/LSP-style framing.
struct NDJSONLineBuffer {
    private var buffer = Data()
    private let newline = Data([0x0A])

    mutating func append(_ data: Data) -> [Data] {
        buffer.append(data)
        var lines: [Data] = []
        while let range = buffer.range(of: newline) {
            let line = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            lines.append(line)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
        }
        return lines
    }
}
