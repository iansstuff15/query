import Foundation

/// Reserved and common SQL words (ANSI plus PostgreSQL / MySQL / SQL Server staples), used for
/// highlighting and completion in the SQL console.
nonisolated enum SQLKeywords {
    static let all: [String] = [
        "ADD", "ALL", "ALTER", "AND", "ANY", "AS", "ASC", "AUTO_INCREMENT", "BEGIN", "BETWEEN", "BIGINT", "BOOLEAN", "BY",
        "CASCADE", "CASE", "CAST", "CHAR", "CHECK", "COALESCE", "COLUMN", "COMMIT", "CONSTRAINT", "COUNT", "CREATE", "CROSS",
        "CURRENT_DATE", "CURRENT_TIMESTAMP", "DATABASE", "DATE", "DECIMAL", "DEFAULT", "DELETE", "DESC", "DESCRIBE", "DISTINCT",
        "DROP", "ELSE", "END", "ESCAPE", "EXCEPT", "EXISTS", "EXPLAIN", "FALSE", "FETCH", "FIRST", "FLOAT", "FOREIGN", "FROM",
        "FULL", "FUNCTION", "GRANT", "GROUP", "HAVING", "IF", "ILIKE", "IN", "INDEX", "INNER", "INSERT", "INT", "INTEGER",
        "INTERSECT", "INTERVAL", "INTO", "IS", "JOIN", "JSON", "KEY", "LAST", "LATERAL", "LEFT", "LIKE", "LIMIT", "MAX", "MIN",
        "NATURAL", "NOT", "NULL", "NULLS", "NUMERIC", "OFFSET", "ON", "OR", "ORDER", "OUTER", "OVER", "PARTITION", "PRIMARY",
        "PROCEDURE", "REFERENCES", "RETURNING", "REVOKE", "RIGHT", "ROLLBACK", "ROW", "ROWS", "SCHEMA", "SELECT", "SEQUENCE",
        "SET", "SHOW", "SMALLINT", "SUM", "TABLE", "TEXT", "THEN", "TIME", "TIMESTAMP", "TOP", "TRANSACTION", "TRIGGER", "TRUE",
        "TRUNCATE", "UNION", "UNIQUE", "UPDATE", "USE", "USING", "VALUES", "VARCHAR", "VIEW", "WHEN", "WHERE", "WINDOW", "WITH",
    ]

    /// Lowercased, for matching.
    static let lowercased: Set<String> = Set(all.map { $0.lowercased() })

    /// Words after which a table name is expected; completion lists tables first there.
    static let tableContext: Set<String> = ["from", "join", "into", "update", "table", "describe", "truncate", "exists"]
}
