import Foundation

nonisolated enum MySQLCatalogQueries {
    static let objects = SQLStatement(sql: """
        SELECT TABLE_SCHEMA, TABLE_NAME, CASE TABLE_TYPE WHEN 'VIEW' THEN 'v' ELSE 'r' END
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
        ORDER BY TABLE_SCHEMA, TABLE_NAME
        """)

    /// Primary-key columns in key order.
    static func primaryKey(of object: DatabaseObject) -> SQLStatement {
        SQLStatement(
            sql: """
                SELECT COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE
                WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND CONSTRAINT_NAME = 'PRIMARY' ORDER BY ORDINAL_POSITION
                """,
            bindings: [object.schema, object.name]
        )
    }

    static func columns(of object: DatabaseObject) -> SQLStatement {
        SQLStatement(
            sql: """
                SELECT COLUMN_NAME, COLUMN_TYPE FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? ORDER BY ORDINAL_POSITION
                """,
            bindings: [object.schema, object.name]
        )
    }
}
