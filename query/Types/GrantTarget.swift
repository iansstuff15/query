import Foundation

/// What a permission applies to: one table (or view), or a whole schema.
nonisolated enum GrantTarget: Hashable, Comparable, Identifiable, Sendable {
    /// Every table in a schema. MySQL / MariaDB keep this as one `schema.*` grant; on PostgreSQL
    /// it's a shortcut that sets each table in the schema.
    case schema(String)
    case table(schema: String, name: String)

    var id: String {
        switch self {
        case .schema(let schema): "\(schema).*"
        case .table(let schema, let name): "\(schema).\(name)"
        }
    }

    var schema: String {
        switch self {
        case .schema(let schema), .table(let schema, _): schema
        }
    }

    /// Schemas first, then their tables, alphabetically.
    static func < (lhs: GrantTarget, rhs: GrantTarget) -> Bool {
        if lhs.schema != rhs.schema { return lhs.schema < rhs.schema }
        switch (lhs, rhs) {
        case (.schema, .table): return true
        case (.table, .schema): return false
        case (.table(_, let left), .table(_, let right)): return left < right
        default: return false
        }
    }
}
