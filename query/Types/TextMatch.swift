import Foundation

/// A successful match: higher `score` ranks first; `offsets` are matched character positions.
nonisolated struct TextMatch: Hashable, Sendable {
    let score: Int
    let offsets: [Int]
}
