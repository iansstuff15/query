import Foundation

/// The kinds of relation the browser lists, mapped from `pg_class.relkind`.
nonisolated enum DatabaseObjectKind: String, CaseIterable, Hashable, Sendable {
    case table
    case partitionedTable
    case view
    case materializedView
    case foreignTable
    case collection
    case index
    case keyspace

    init?(relkind: String) {
        switch relkind {
        case "r": self = .table
        case "p": self = .partitionedTable
        case "v": self = .view
        case "m": self = .materializedView
        case "f": self = .foreignTable
        default: return nil
        }
    }

    var systemImage: String {
        switch self {
        case .table: "tablecells"
        case .partitionedTable: "square.split.2x2"
        case .view: "eye"
        case .materializedView: "square.stack.3d.up"
        case .foreignTable: "link"
        case .collection: "doc.on.doc"
        case .index: "magnifyingglass.circle"
        case .keyspace: "key"
        }
    }
}
