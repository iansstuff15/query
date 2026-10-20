import Foundation

/// Sidebar grouping of objects by schema.
nonisolated struct SchemaSection: Identifiable, Hashable, Sendable {
    let schema: String
    let objects: [DatabaseObject]

    var id: String { schema }
}
