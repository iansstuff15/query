import Foundation

/// Minimal RESP2 client for Redis / Valkey: request/response, no pipelining or pub/sub.
actor RESPConnection {
    private let stream: TCPStream

    init(stream: TCPStream) {
        self.stream = stream
    }

    func open() async throws {
        try await stream.open()
    }

    func command(_ arguments: [String]) async throws -> RESPValue {
        try await stream.write(Self.encode(arguments))
        let reply = try await readValue()
        if case .error(let message) = reply {
            throw RESPError(message: message)
        }
        return reply
    }

    func close() async {
        await stream.close()
    }

    static func encode(_ arguments: [String]) -> Data {
        var data = Data("*\(arguments.count)\r\n".utf8)
        for argument in arguments {
            let bytes = Data(argument.utf8)
            data.append(Data("$\(bytes.count)\r\n".utf8))
            data.append(bytes)
            data.append(Data("\r\n".utf8))
        }
        return data
    }

    private func readValue() async throws -> RESPValue {
        let line = String(decoding: try await stream.read(until: Data("\r\n".utf8)), as: UTF8.self)
        guard let prefix = line.first else { throw DatabaseError.protocolViolation }
        let body = String(line.dropFirst())
        switch prefix {
        case "+": return .simple(body)
        case "-": return .error(body)
        case ":": return .integer(Int(body) ?? 0)
        case "$":
            guard let length = Int(body) else { throw DatabaseError.protocolViolation }
            guard length >= 0 else { return .bulk(nil) }
            let bytes = try await stream.read(exactly: length + 2)
            return .bulk(String(decoding: bytes.prefix(length), as: UTF8.self))
        case "*":
            guard let count = Int(body) else { throw DatabaseError.protocolViolation }
            guard count >= 0 else { return .array(nil) }
            var values: [RESPValue] = []
            for _ in 0..<count { values.append(try await readValue()) }
            return .array(values)
        default:
            throw DatabaseError.protocolViolation
        }
    }
}

nonisolated struct RESPError: Error, Sendable {
    let message: String
}
