import Foundation

/// A browsable relation (table, view, …) inside a schema.
nonisolated struct DatabaseObject: Identifiable, Hashable, Sendable {
    let schema: String
    let name: String
    let kind: DatabaseObjectKind

    /// `schema.name`, unique per database.
    var id: String { "\(schema).\(name)" }
}
