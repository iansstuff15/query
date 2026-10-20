import Foundation
import os

/// One authenticated TDS session. TLS uses TDS 8.0 strict mode (TLS before PRELOGIN).
actor TDSConnection {
    private let stream: TCPStream
    private var packetSize = 4_096
    private var packetID: UInt8 = 1

    private init(stream: TCPStream) {
        self.stream = stream
    }

    static func connect(endpoint: ServerEndpoint, verifyCertificate: Bool, useTLS: Bool) async throws -> TDSConnection {
        let stream = TCPStream(
            host: endpoint.host, port: endpoint.port, useTLS: useTLS,
            verifyCertificate: verifyCertificate, applicationProtocols: useTLS ? ["tds/8.0"] : []
        )
        try await stream.open()
        let connection = TDSConnection(stream: stream)
        try await connection.handshake(endpoint: endpoint, strict: useTLS)
        return connection
    }

    func execute(_ statement: SQLStatement) async throws -> [[String?]] {
        if statement.bindings.isEmpty {
            try await send(.sqlBatch, payload: TDSMessages.sqlBatch(statement.sql))
        } else {
            try await send(.rpc, payload: TDSMessages.executeSQL(statement.sql, bindings: statement.bindings))
        }
        let outcome = try TDSTokenParser.parse(try await receive())
        if !outcome.errors.isEmpty {
            AppLog.database.error("SQL Server error: \(outcome.errors.joined(separator: "; "), privacy: .private)")
            throw DatabaseError.queryFailed
        }
        return outcome.rows
    }

    func close() async {
        await stream.close()
    }

    private func handshake(endpoint: ServerEndpoint, strict: Bool) async throws {
        try await send(.preLogin, payload: TDSMessages.preLogin(encryption: strict ? .strict : .notSupported))
        _ = try await receive()
        let login = TDSMessages.login7(
            username: endpoint.username ?? "sa",
            password: endpoint.password ?? "",
            database: endpoint.database ?? "",
            serverName: endpoint.host,
            packetSize: UInt32(packetSize)
        )
        try await send(.login7, payload: login)
        let outcome = try TDSTokenParser.parse(try await receive())
        guard outcome.loggedIn else {
            AppLog.database.error("SQL Server login failed: \(outcome.errors.joined(separator: "; "), privacy: .private)")
            throw DatabaseError.connectionFailed
        }
        if let size = outcome.packetSize { packetSize = size }
    }

    /// Splits `payload` into packets of the negotiated size.
    private func send(_ type: TDSMessages.PacketType, payload: Data) async throws {
        let chunkSize = packetSize - 8
        var offset = payload.startIndex
        repeat {
            let end = min(offset + chunkSize, payload.endIndex)
            var header = TDSWriter()
            header.uint8(type.rawValue)
            header.uint8(end == payload.endIndex ? 0x01 : 0x00)
            header.uint16BE(UInt16(8 + end - offset))
            header.uint16BE(0)
            header.uint8(packetID)
            header.uint8(0)
            packetID &+= 1
            try await stream.write(header.data + payload[offset..<end])
            offset = end
        } while offset < payload.endIndex
    }

    /// Reads packets until end-of-message and returns the concatenated payload.
    private func receive() async throws -> Data {
        var payload = Data()
        while true {
            let header = try await stream.read(exactly: 8)
            let status = header[header.startIndex + 1]
            let length = Int(header[header.startIndex + 2]) << 8 | Int(header[header.startIndex + 3])
            guard length >= 8 else { throw DatabaseError.protocolViolation }
            payload.append(try await stream.read(exactly: length - 8))
            if status & 0x01 != 0 { return payload }
        }
    }
}
