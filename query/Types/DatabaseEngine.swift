import Foundation

/// Every engine TablePlus ships a connection form for (`Resources/*Form.nib`).
nonisolated enum DatabaseEngine: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case postgreSQL
    case cockroachDB
    case greenplum
    case redshift
    case vertica
    case mySQL
    case mariaDB
    case sqlServer
    case oracle
    case sqlite
    case duckDB
    case libSQL
    case cloudflareD1
    case clickHouse
    case bigQuery
    case snowflake
    case cassandra
    case redis
    case mongoDB
    case elasticsearch
    case dynamoDB

    var id: String { rawValue }
}
