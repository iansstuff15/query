import Foundation

/// Little-endian byte builder for TDS messages.
nonisolated struct TDSWriter {
    private(set) var data = Data()

    mutating func uint8(_ value: UInt8) { data.append(value) }

    mutating func uint16LE(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

    mutating func uint16BE(_ value: UInt16) { withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) } }

    mutating func uint32LE(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

    mutating func uint64LE(_ value: UInt64) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

    mutating func bytes(_ value: Data) { data.append(value) }

    mutating func utf16(_ value: String) { data.append(Self.utf16(value)) }

    /// `B_VARCHAR`: 1-byte character count + UTF-16LE.
    mutating func bVarChar(_ value: String) {
        uint8(UInt8(clamping: value.utf16.count))
        utf16(value)
    }

    static func utf16(_ value: String) -> Data {
        var data = Data(capacity: value.utf16.count * 2)
        for unit in value.utf16 {
            withUnsafeBytes(of: unit.littleEndian) { data.append(contentsOf: $0) }
        }
        return data
    }
}
