import Foundation

nonisolated enum OracleCatalogQueries {
    /// Tables and views owned by non-Oracle-maintained users.
    static let objects = SQLStatement(sql: """
        SELECT owner, object_name, CASE object_type WHEN 'VIEW' THEN 'v' ELSE 'r' END
        FROM all_objects
        WHERE object_type IN ('TABLE', 'VIEW')
          AND owner IN (SELECT username FROM all_users WHERE oracle_maintained = 'N')
        ORDER BY owner, object_name
        """)

    static func columns(of object: DatabaseObject) -> SQLStatement {
        SQLStatement(
            sql: "SELECT column_name, data_type FROM all_tab_columns WHERE owner = :1 AND table_name = :2 ORDER BY column_id",
            bindings: [object.schema, object.name]
        )
    }
}
