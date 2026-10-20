import Foundation

/// Engines that share a wire protocol / driver.
nonisolated enum EngineFamily: String, Hashable, Sendable {
    case postgres
    case mySQL
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
}
