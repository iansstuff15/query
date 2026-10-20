import Foundation

/// An object ranked by Open Anything, with the name offsets to highlight.
nonisolated struct SearchMatch: Identifiable, Hashable, Sendable {
    let object: DatabaseObject
    let score: Int
    let nameOffsets: [Int]

    var id: String { object.id }
}
