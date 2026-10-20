import Foundation

nonisolated enum DuckDBCatalogQueries {
    static let objects = SQLStatement(sql: """
        SELECT table_schema, table_name, CASE table_type WHEN 'VIEW' THEN 'v' ELSE 'r' END
        FROM information_schema.tables
        WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
        ORDER BY table_schema, table_name
        """)

    static func columns(of object: DatabaseObject) -> SQLStatement {
        SQLStatement(
            sql: """
                SELECT column_name, data_type FROM information_schema.columns
                WHERE table_schema = $1 AND table_name = $2 ORDER BY ordinal_position
                """,
            bindings: [object.schema, object.name]
        )
    }
}
