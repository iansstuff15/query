import Foundation

nonisolated enum SnowflakeCatalogQueries {
    static let objects = SQLStatement(sql: """
        SELECT table_schema, table_name, CASE table_type WHEN 'VIEW' THEN 'v' WHEN 'MATERIALIZED VIEW' THEN 'm' ELSE 'r' END
        FROM information_schema.tables
        WHERE table_schema <> 'INFORMATION_SCHEMA'
        ORDER BY table_schema, table_name
        """)

    static func columns(of object: DatabaseObject) -> SQLStatement {
        SQLStatement(
            sql: """
                SELECT column_name, data_type FROM information_schema.columns
                WHERE table_schema = ? AND table_name = ? ORDER BY ordinal_position
                """,
            bindings: [object.schema, object.name]
        )
    }
}
