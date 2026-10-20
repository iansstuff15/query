import Foundation

nonisolated enum ClickHouseCatalogQueries {
    static let objects = SQLStatement(sql: """
        SELECT database, name, multiIf(engine = 'View', 'v', engine = 'MaterializedView', 'm', 'r')
        FROM system.tables
        WHERE database NOT IN ('system', 'INFORMATION_SCHEMA', 'information_schema') AND NOT is_temporary
          AND NOT startsWith(name, '.inner')
        ORDER BY database, name
        """)

    static func columns(of object: DatabaseObject) -> SQLStatement {
        SQLStatement(
            sql: "SELECT name, type FROM system.columns WHERE database = {p1:String} AND table = {p2:String} ORDER BY position",
            bindings: [object.schema, object.name]
        )
    }
}
