import Foundation

/// A column name plus its server-formatted type (e.g. `character varying(255)`).
nonisolated struct ColumnInfo: Identifiable, Hashable, Sendable {
    let name: String
    let dataType: String

    var id: String { name }
}
