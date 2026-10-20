import CryptoKit
import Foundation
import os

/// PostgreSQL frontend/backend protocol v3, simple-query subset: startup, cleartext / MD5
/// password auth, `Q` queries and text-format rows. Used for Vertica, which speaks this
/// protocol but rejects PostgresNIO's extended-query (Parse/Bind) flow.
actor PGSimpleQueryConnection {
    private let stream: TCPStream

    private init(stream: TCPStream) {
        self.stream = stream
    }

    static func connect(endpoint: ServerEndpoint) async throws -> PGSimpleQueryConnection {
        let stream = TCPStream(host: endpoint.host, port: endpoint.port, useTLS: false)
        try await stream.open()
        let connection = PGSimpleQueryConnection(stream: stream)
        try await connection.startup(user: endpoint.username ?? "dbadmin", password: endpoint.password ?? "", database: endpoint.database ?? "")
        return connection
    }

    func query(_ sql: String) async throws -> [[String?]] {
        var body = Data(sql.utf8)
        body.append(0)
        try await send(type: "Q", body: body)
        var rows: [[String?]] = []
        var errors: [String] = []
        while true {
            let (type, payload) = try await receive()
            switch type {
            case "D": rows.append(try Self.dataRow(payload))
            case "E": errors.append(Self.errorMessage(payload))
            case "Z": // ReadyForQuery
                if !errors.isEmpty {
                    AppLog.database.error("Vertica error: \(errors.joined(separator: "; "), privacy: .private)")
                    throw DatabaseError.queryFailed
                }
                return rows
            default: continue // RowDescription, CommandComplete, notices, parameter status…
            }
        }
    }

    func close() async {
        try? await send(type: "X", body: Data())
        await stream.close()
    }

    private func startup(user: String, password: String, database: String) async throws {
        var body = Data()
        body.append(contentsOf: Self.int32(196_608)) // protocol 3.0
        for (key, value) in [("user", user), ("database", database), ("client_encoding", "UTF8")] where !value.isEmpty {
            body.append(contentsOf: Array(key.utf8) + [0] + Array(value.utf8) + [0])
        }
        body.append(0)
        try await stream.write(Data(Self.int32(Int32(body.count + 4))) + body)
        while true {
            let (type, payload) = try await receive()
            switch type {
            case "R":
                let code = Self.readInt32(payload, at: 0)
                switch code {
                case 0: continue
                case 3: try await sendPassword(password)
                case 5: try await sendPassword(Self.md5Password(user: user, password: password, salt: payload.subdata(in: payload.startIndex + 4..<payload.startIndex + 8)))
                default:
                    AppLog.database.error("Vertica requested unsupported authentication method \(code)")
                    throw DatabaseError.connectionFailed
                }
            case "E":
                AppLog.database.error("Vertica startup failed: \(Self.errorMessage(payload), privacy: .private)")
                throw DatabaseError.connectionFailed
            case "Z":
                return
            default:
                continue
            }
        }
    }

    private func sendPassword(_ password: String) async throws {
        var body = Data(password.utf8)
        body.append(0)
        try await send(type: "p", body: body)
    }

    private func send(type: Character, body: Data) async throws {
        var message = Data([type.asciiValue ?? 0])
        message.append(contentsOf: Self.int32(Int32(body.count + 4)))
        message.append(body)
        try await stream.write(message)
    }

    private func receive() async throws -> (Character, Data) {
        let header = try await stream.read(exactly: 5)
        let type = Character(UnicodeScalar(header[header.startIndex]))
        let length = Int(Self.readInt32(header, at: 1))
        guard length >= 4 else { throw DatabaseError.protocolViolation }
        return (type, try await stream.read(exactly: length - 4))
    }

    // MARK: - Message parsing (internal for tests)

    static func dataRow(_ payload: Data) throws -> [String?] {
        guard payload.count >= 2 else { throw DatabaseError.protocolViolation }
        let base = payload.startIndex
        let count = Int(UInt16(payload[base]) << 8 | UInt16(payload[base + 1]))
        var offset = 2
        var values: [String?] = []
        for _ in 0..<count {
            guard offset + 4 <= payload.count else { throw DatabaseError.protocolViolation }
            let length = Int(readInt32(payload, at: offset))
            offset += 4
            if length < 0 {
                values.append(nil)
                continue
            }
            guard offset + length <= payload.count else { throw DatabaseError.protocolViolation }
            values.append(String(decoding: payload.subdata(in: base + offset..<base + offset + length), as: UTF8.self))
            offset += length
        }
        return values
    }

    /// The `M` (message) field of an ErrorResponse.
    static func errorMessage(_ payload: Data) -> String {
        payload.split(separator: 0).first { $0.first == UInt8(ascii: "M") }
            .map { String(decoding: $0.dropFirst(), as: UTF8.self) } ?? "unknown error"
    }

    static func md5Password(user: String, password: String, salt: Data) -> String {
        let inner = hex(Insecure.MD5.hash(data: Data((password + user).utf8)))
        return "md5" + hex(Insecure.MD5.hash(data: Data(inner.utf8) + salt))
    }

    private static func hex(_ digest: Insecure.MD5.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func int32(_ value: Int32) -> [UInt8] {
        withUnsafeBytes(of: value.bigEndian, Array.init)
    }

    static func readInt32(_ data: Data, at offset: Int) -> Int32 {
        let base = data.startIndex + offset
        return Int32(bitPattern: UInt32(data[base]) << 24 | UInt32(data[base + 1]) << 16 | UInt32(data[base + 2]) << 8 | UInt32(data[base + 3]))
    }
}
