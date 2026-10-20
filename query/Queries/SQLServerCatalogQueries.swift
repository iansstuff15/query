import Foundation

/// T-SQL catalog queries; every column is cast to NVARCHAR so the TDS reader sees text.
nonisolated enum SQLServerCatalogQueries {
    static let objects = SQLStatement(sql: """
        SELECT CAST(s.name AS NVARCHAR(4000)), CAST(o.name AS NVARCHAR(4000)),
               CAST(CASE o.type WHEN 'V' THEN 'v' ELSE 'r' END AS NVARCHAR(1))
        FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
        WHERE o.type IN ('U', 'V') AND o.is_ms_shipped = 0
        ORDER BY s.name, o.name
        """)

    static func columns(of object: DatabaseObject) -> SQLStatement {
        let dialect = SQLServerDialect()
        return SQLStatement(
            sql: """
                SELECT CAST(c.name AS NVARCHAR(4000)), CAST(TYPE_NAME(c.user_type_id) AS NVARCHAR(4000))
                FROM sys.columns c WHERE c.object_id = OBJECT_ID(@p1) ORDER BY c.column_id
                """,
            bindings: [dialect.table(object)]
        )
    }
}
