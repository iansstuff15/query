import Foundation

/// Engines that speak the PostgreSQL wire protocol, which differ in catalogs and markers.
/// Vertica uses `VerticaDatabaseClient` (simple-query protocol) but shares the catalog SQL.
nonisolated enum PostgresFlavor: String, Hashable, Sendable {
    case postgres
    case cockroach
    case greenplum
    case redshift
    case vertica

    init?(engine: DatabaseEngine) {
        switch engine {
        case .postgreSQL: self = .postgres
        case .cockroachDB: self = .cockroach
        case .greenplum: self = .greenplum
        case .redshift: self = .redshift
        case .vertica: self = .vertica
        default: return nil
        }
    }

    var dialect: PostgresDialect {
        switch self {
        case .redshift: .redshift
        case .vertica: .vertica
        default: .postgres
        }
    }
}
