import Foundation

/// Parses a server → client TDS token stream into text rows.
nonisolated struct TDSTokenParser {
    struct Outcome {
        var rows: [[String?]] = []
        var errors: [String] = []
        var loggedIn = false
        var packetSize: Int?
    }

    static func parse(_ payload: Data) throws -> Outcome {
        var reader = TDSReader(payload)
        var outcome = Outcome()
        var columns: [TDSColumn] = []
        while !reader.isAtEnd {
            let token = try reader.uint8()
            switch token {
            case 0x81: // COLMETADATA
                columns = try columnMetadata(&reader)
                outcome.rows.removeAll()
            case 0xD1: // ROW
                outcome.rows.append(try columns.map { try value(&reader, column: $0) })
            case 0xD2: // NBCROW
                let bitmap = try reader.bytes((columns.count + 7) / 8)
                outcome.rows.append(try columns.enumerated().map { index, column in
                    let isNull = bitmap[bitmap.startIndex + index / 8] & (1 << (index % 8)) != 0
                    return isNull ? nil : try value(&reader, column: column)
                })
            case 0xAA, 0xAB: // ERROR, INFO
                let length = Int(try reader.uint16())
                var message = TDSReader(try reader.bytes(length))
                let number = try message.uint32()
                try message.skip(2)
                let text = try message.usVarChar()
                if token == 0xAA { outcome.errors.append("\(number): \(text)") }
            case 0xAD: // LOGINACK
                outcome.loggedIn = true
                try reader.skip(Int(try reader.uint16()))
            case 0xE3: // ENVCHANGE
                let length = Int(try reader.uint16())
                var change = TDSReader(try reader.bytes(length))
                if try change.uint8() == 4, let size = Int(try change.bVarChar()) { outcome.packetSize = size }
            case 0xAE: // FEATUREEXTACK
                while try reader.uint8() != 0xFF { try reader.skip(Int(try reader.uint32())) }
            case 0xA9, 0xA5, 0xA4: // ORDER, COLINFO, TABNAME
                try reader.skip(Int(try reader.uint16()))
            case 0x79: // RETURNSTATUS
                try reader.skip(4)
            case 0xFD, 0xFE, 0xFF: // DONE, DONEPROC, DONEINPROC
                try reader.skip(12)
            case 0xAC: // RETURNVALUE (output params; never requested)
                throw DatabaseError.protocolViolation
            default:
                throw DatabaseError.protocolViolation
            }
        }
        return outcome
    }

    private static func columnMetadata(_ reader: inout TDSReader) throws -> [TDSColumn] {
        let count = Int(try reader.uint16())
        guard count != 0xFFFF else { return [] }
        return try (0..<count).map { _ in
            try reader.skip(4 + 2) // user type, flags
            let type = try reader.uint8()
            var scale: UInt8 = 0
            let encoding: TDSColumn.Encoding
            switch type {
            case 0x1F: encoding = .fixed(size: 0)
            case 0x30, 0x32: encoding = .fixed(size: 1)
            case 0x34: encoding = .fixed(size: 2)
            case 0x38, 0x3B, 0x3A, 0x7A: encoding = .fixed(size: 4)
            case 0x7F, 0x3E, 0x3D, 0x3C: encoding = .fixed(size: 8)
            case 0x26, 0x68, 0x6D, 0x6E, 0x6F, 0x24:
                try reader.skip(1)
                encoding = .byteLength
            case 0x6A, 0x6C:
                try reader.skip(1)
                try reader.skip(1)
                scale = try reader.uint8()
                encoding = .byteLength
            case 0x28:
                encoding = .byteLength
            case 0x29, 0x2A, 0x2B:
                scale = try reader.uint8()
                encoding = .byteLength
            case 0xA7, 0xAF, 0xE7, 0xEF:
                let maxLength = try reader.uint16()
                try reader.skip(5)
                encoding = maxLength == 0xFFFF ? .plp : .shortLength
            case 0xA5, 0xAD:
                encoding = try reader.uint16() == 0xFFFF ? .plp : .shortLength
            case 0x23, 0x63, 0x22:
                try reader.skip(4)
                if type != 0x22 { try reader.skip(5) }
                let parts = Int(try reader.uint8())
                for _ in 0..<parts { _ = try reader.usVarChar() }
                encoding = .long
            case 0xF1:
                if try reader.uint8() != 0 {
                    _ = try reader.bVarChar()
                    _ = try reader.bVarChar()
                    _ = try reader.usVarChar()
                }
                encoding = .plp
            default:
                throw DatabaseError.protocolViolation
            }
            let name = try reader.bVarChar()
            return TDSColumn(type: type, encoding: encoding, name: name, scale: scale)
        }
    }

    private static func value(_ reader: inout TDSReader, column: TDSColumn) throws -> String? {
        let bytes: Data?
        switch column.encoding {
        case .fixed(let size):
            bytes = size == 0 ? nil : try reader.bytes(size)
        case .byteLength:
            let length = Int(try reader.uint8())
            bytes = length == 0 ? nil : try reader.bytes(length)
        case .shortLength:
            let length = try reader.uint16()
            bytes = length == 0xFFFF ? nil : try reader.bytes(Int(length))
        case .plp:
            let total = try reader.uint64()
            if total == UInt64.max {
                bytes = nil
            } else {
                var collected = Data()
                while true {
                    let chunk = Int(try reader.uint32())
                    if chunk == 0 { break }
                    collected.append(try reader.bytes(chunk))
                }
                bytes = collected
            }
        case .long:
            let pointerLength = Int(try reader.uint8())
            if pointerLength == 0 {
                bytes = nil
            } else {
                try reader.skip(pointerLength + 8)
                bytes = try reader.bytes(Int(try reader.uint32()))
            }
        }
        guard let bytes else { return nil }
        return render(bytes, column: column)
    }

    /// Text for character types and integers; other types should be CAST to NVARCHAR in SQL.
    private static func render(_ bytes: Data, column: TDSColumn) -> String {
        if column.isUnicode { return TDSReader.string(fromUTF16: bytes) }
        if column.isCharacter { return String(decoding: bytes, as: UTF8.self) }
        switch (column.type, bytes.count) {
        case (0x30, 1), (0x26, 1): return String(bytes[bytes.startIndex])
        case (0x32, 1), (0x68, 1): return bytes[bytes.startIndex] == 0 ? "false" : "true"
        case (0x34, 2), (0x26, 2): return String(bytes.withUnsafeBytes { Int16(littleEndian: $0.loadUnaligned(as: Int16.self)) })
        case (0x38, 4), (0x26, 4): return String(bytes.withUnsafeBytes { Int32(littleEndian: $0.loadUnaligned(as: Int32.self)) })
        case (0x7F, 8), (0x26, 8): return String(bytes.withUnsafeBytes { Int64(littleEndian: $0.loadUnaligned(as: Int64.self)) })
        case (0x3E, 8), (0x6D, 8): return String(bytes.withUnsafeBytes { Double(bitPattern: UInt64(littleEndian: $0.loadUnaligned(as: UInt64.self))) })
        default: return bytes.map { String(format: "%02X", $0) }.joined()
        }
    }
}
