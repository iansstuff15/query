import Foundation

/// Builders for the client → server TDS messages this app sends.
nonisolated enum TDSMessages {
    enum PacketType: UInt8 {
        case sqlBatch = 0x01
        case rpc = 0x03
        case login7 = 0x10
        case preLogin = 0x12
    }

    enum Encryption: UInt8 {
        case notSupported = 0x02
        case strict = 0x08
    }

    /// Latin1_General_CI_AS — the collation sent with NVARCHAR parameters.
    static let collation = Data([0x09, 0x04, 0xD0, 0x00, 0x34])

    static func preLogin(encryption: Encryption) -> Data {
        let options: [(UInt8, Data)] = [
            (0x00, Data([0x10, 0x00, 0x00, 0x00, 0x00, 0x00])), // VERSION
            (0x01, Data([encryption.rawValue])),                  // ENCRYPTION
            (0x02, Data([0x00])),                                 // INSTOPT
            (0x03, Data([0x00, 0x00, 0x00, 0x00])),               // THREADID
            (0x04, Data([0x00])),                                 // MARS off
        ]
        var header = TDSWriter()
        var payload = Data()
        let headerLength = options.count * 5 + 1
        for (token, value) in options {
            header.uint8(token)
            header.uint16BE(UInt16(headerLength + payload.count))
            header.uint16BE(UInt16(value.count))
            payload.append(value)
        }
        header.uint8(0xFF)
        return header.data + payload
    }

    static func login7(username: String, password: String, database: String, serverName: String, packetSize: UInt32) -> Data {
        let hostName = "query"
        let appName = "query"
        let strings = [hostName, username, password, appName, serverName, "", "query", "", database]
        var variable = Data()
        var pointers = TDSWriter()
        let fixedLength = 94
        for (index, value) in strings.enumerated() {
            pointers.uint16LE(UInt16(fixedLength + variable.count))
            pointers.uint16LE(UInt16(value.utf16.count))
            variable.append(index == 2 ? obfuscate(password) : TDSWriter.utf16(value))
        }

        var writer = TDSWriter()
        writer.uint32LE(UInt32(fixedLength + variable.count))
        writer.uint32LE(0x7400_0004)   // TDS 7.4
        writer.uint32LE(packetSize)
        writer.uint32LE(0x0700_0000)   // client program version
        writer.uint32LE(UInt32(ProcessInfo.processInfo.processIdentifier))
        writer.uint32LE(0)             // connection ID
        writer.uint8(0xE0)             // USE_DB_ON | INIT_DB_FATAL | SET_LANG_ON
        writer.uint8(0x03)             // INIT_LANG_FATAL | ODBC_ON
        writer.uint8(0x00)             // type flags
        writer.uint8(0x00)             // option flags 3
        writer.uint32LE(0)             // client time zone
        writer.uint32LE(0x0409)        // client LCID
        writer.bytes(pointers.data)
        writer.bytes(Data(count: 6))   // client ID (MAC)
        let tail = UInt16(fixedLength + variable.count)
        for _ in 0..<3 {               // SSPI, AtchDBFile, ChangePassword
            writer.uint16LE(tail)
            writer.uint16LE(0)
        }
        writer.uint32LE(0)             // cbSSPILong
        writer.bytes(variable)
        return writer.data
    }

    /// ALL_HEADERS with a transaction descriptor (required for batches and RPC since TDS 7.2).
    static var allHeaders: Data {
        var writer = TDSWriter()
        writer.uint32LE(22)
        writer.uint32LE(18)
        writer.uint16LE(2)
        writer.uint64LE(0)
        writer.uint32LE(1)
        return writer.data
    }

    static func sqlBatch(_ sql: String) -> Data {
        allHeaders + TDSWriter.utf16(sql)
    }

    /// `sp_executesql @stmt, @params, @p1, @p2, …` with every value as NVARCHAR(MAX).
    static func executeSQL(_ sql: String, bindings: [String]) -> Data {
        var writer = TDSWriter()
        writer.bytes(allHeaders)
        writer.uint16LE(0xFFFF)
        writer.uint16LE(10) // sp_executesql
        writer.uint16LE(0)  // option flags
        appendNVarCharMax(&writer, name: "", value: sql)
        let declarations = bindings.indices.map { "@p\($0 + 1) nvarchar(max)" }.joined(separator: ", ")
        appendNVarCharMax(&writer, name: "", value: declarations)
        for (index, value) in bindings.enumerated() {
            appendNVarCharMax(&writer, name: "@p\(index + 1)", value: value)
        }
        return writer.data
    }

    private static func appendNVarCharMax(_ writer: inout TDSWriter, name: String, value: String) {
        writer.bVarChar(name)
        writer.uint8(0)          // status flags
        writer.uint8(0xE7)       // NVARCHAR
        writer.uint16LE(0xFFFF)  // MAX → PLP
        writer.bytes(collation)
        let bytes = TDSWriter.utf16(value)
        writer.uint64LE(UInt64(bytes.count))
        if !bytes.isEmpty {
            writer.uint32LE(UInt32(bytes.count))
            writer.bytes(bytes)
        }
        writer.uint32LE(0)       // PLP terminator
    }

    /// LOGIN7 password scrambling: swap nibbles, then XOR 0xA5.
    static func obfuscate(_ password: String) -> Data {
        Data(TDSWriter.utf16(password).map { byte in ((byte << 4) | (byte >> 4)) ^ 0xA5 })
    }
}
