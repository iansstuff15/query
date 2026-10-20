import Foundation

/// A RESP2 reply.
nonisolated indirect enum RESPValue: Hashable, Sendable {
    case simple(String)
    case error(String)
    case integer(Int)
    case bulk(String?)
    case array([RESPValue]?)

    var string: String? {
        switch self {
        case .simple(let value): value
        case .bulk(let value): value
        case .integer(let value): String(value)
        default: nil
        }
    }

    var array: [RESPValue] {
        if case .array(let values?) = self { return values }
        return []
    }
}
