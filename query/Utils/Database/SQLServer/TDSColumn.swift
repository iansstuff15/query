import Foundation

/// Result column metadata from a COLMETADATA token: enough to decode or skip each value.
nonisolated struct TDSColumn: Sendable {
    enum Encoding: Sendable {
        /// Fixed-length value of `size` bytes.
        case fixed(size: Int)
        /// 1-byte length prefix (INTN, DECIMALN, DATETIME2N, …).
        case byteLength
        /// 2-byte length prefix; 0xFFFF means NULL.
        case shortLength
        /// Partially length-prefixed (MAX types).
        case plp
        /// TEXT / NTEXT / IMAGE: text pointer + timestamp + 4-byte length.
        case long
    }

    let type: UInt8
    let encoding: Encoding
    let name: String
    let scale: UInt8

    var isUnicode: Bool { [0xE7, 0xEF, 0x63].contains(type) }
    var isCharacter: Bool { [0xA7, 0xAF, 0x23, 0x27, 0x2F].contains(type) || isUnicode }
}
