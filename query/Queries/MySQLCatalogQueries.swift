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

    /// Columns the current user can update: not virtual or stored generated, granted UPDATE
    /// (`PRIVILEGES` lists the current user's), and not in a view that can't be updated.
    static func editableColumns(of object: DatabaseObject) -> SQLStatement {
        SQLStatement(
            sql: """
                SELECT c.COLUMN_NAME FROM information_schema.COLUMNS c
                WHERE c.TABLE_SCHEMA = ? AND c.TABLE_NAME = ?
                  AND c.EXTRA NOT LIKE '%VIRTUAL GENERATED%' AND c.EXTRA NOT LIKE '%STORED GENERATED%'
                  AND FIND_IN_SET('update', c.PRIVILEGES) > 0
                  AND NOT EXISTS (
                    SELECT 1 FROM information_schema.VIEWS v
                    WHERE v.TABLE_SCHEMA = c.TABLE_SCHEMA AND v.TABLE_NAME = c.TABLE_NAME AND v.IS_UPDATABLE = 'NO'
                  )
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
