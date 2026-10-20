import Foundation

/// Little-endian cursor over a TDS token stream.
nonisolated struct TDSReader {
    private let data: Data
    private(set) var offset: Int

    init(_ data: Data) {
        self.data = data
        offset = data.startIndex
    }

    var isAtEnd: Bool { offset >= data.endIndex }

    mutating func uint8() throws -> UInt8 {
        try ensure(1)
        defer { offset += 1 }
        return data[offset]
    }

    mutating func uint16() throws -> UInt16 {
        try ensure(2)
        defer { offset += 2 }
        return UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    mutating func uint32() throws -> UInt32 {
        try ensure(4)
        var value: UInt32 = 0
        for index in 0..<4 { value |= UInt32(data[offset + index]) << (8 * index) }
        offset += 4
        return value
    }

    mutating func uint64() throws -> UInt64 {
        try ensure(8)
        var value: UInt64 = 0
        for index in 0..<8 { value |= UInt64(data[offset + index]) << (8 * index) }
        offset += 8
        return value
    }

    mutating func bytes(_ count: Int) throws -> Data {
        try ensure(count)
        defer { offset += count }
        return data.subdata(in: offset..<(offset + count))
    }

    mutating func skip(_ count: Int) throws {
        try ensure(count)
        offset += count
    }

    /// UTF-16LE string of `characters` code units.
    mutating func utf16(characters: Int) throws -> String {
        Self.string(fromUTF16: try bytes(characters * 2))
    }

    mutating func bVarChar() throws -> String {
        try utf16(characters: Int(try uint8()))
    }

    mutating func usVarChar() throws -> String {
        try utf16(characters: Int(try uint16()))
    }

    static func string(fromUTF16 data: Data) -> String {
        var units: [UInt16] = []
        units.reserveCapacity(data.count / 2)
        var index = data.startIndex
        while index + 1 < data.endIndex {
            units.append(UInt16(data[index]) | UInt16(data[index + 1]) << 8)
            index += 2
        }
        return String(decoding: units, as: UTF16.self)
    }

    private func ensure(_ count: Int) throws {
        guard count >= 0, offset + count <= data.endIndex else { throw DatabaseError.protocolViolation }
    }
}
