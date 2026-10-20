import Foundation

/// A highlighted span of SQL in the console editor; `range` is in UTF-16 units, as AppKit expects.
nonisolated struct SQLToken: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case keyword
        case table
        case string
        case number
        case comment
    }

    let kind: Kind
    let range: NSRange
}
