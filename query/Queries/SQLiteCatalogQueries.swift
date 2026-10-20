import Foundation

/// Catalog SQL for SQLite-compatible engines (SQLite, libSQL/Turso, Cloudflare D1).
nonisolated enum SQLiteCatalogQueries {
    static let objects = SQLStatement(sql: """
        SELECT 'main', name, CASE type WHEN 'view' THEN 'v' ELSE 'r' END
        FROM sqlite_schema
        WHERE type IN ('table', 'view')
          AND name NOT LIKE 'sqlite\\_%' ESCAPE '\\'
          AND name NOT LIKE '\\_cf\\_%' ESCAPE '\\'
          AND name NOT LIKE 'libsql\\_%' ESCAPE '\\'
        ORDER BY name
        """)

    static func columns(of object: DatabaseObject) -> SQLStatement {
        SQLStatement(sql: "SELECT name, type FROM pragma_table_info(?1, ?2) ORDER BY cid", bindings: [object.name, object.schema])
    }
}
