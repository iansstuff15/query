import Foundation

/// A result-set column; `id` is its position in each row's `values`.
nonisolated struct ResultColumn: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
}
