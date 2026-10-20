import Foundation

/// Catalog queries per PostgreSQL-protocol flavor. Every result column is text.
nonisolated enum PostgresCatalogQueries {
    static func objects(_ flavor: PostgresFlavor) -> SQLStatement {
        switch flavor {
        case .postgres, .greenplum:
            SQLStatement(sql: """
                SELECT n.nspname::text, c.relname::text, c.relkind::text
                FROM pg_catalog.pg_class c
                JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                WHERE c.relkind IN ('r', 'p', 'v', 'm', 'f')
                  AND NOT c.relispartition
                  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'gp_toolkit')
                  AND n.nspname NOT LIKE 'pg\\_toast%'
                  AND n.nspname NOT LIKE 'pg\\_temp\\_%'
                ORDER BY n.nspname, c.relname
                """)
        case .cockroach, .redshift:
            SQLStatement(sql: """
                SELECT table_schema::text, table_name::text,
                       CASE table_type WHEN 'VIEW' THEN 'v' WHEN 'MATERIALIZED VIEW' THEN 'm' ELSE 'r' END
                FROM information_schema.tables
                WHERE table_schema NOT IN ('pg_catalog', 'information_schema', 'crdb_internal', 'pg_extension', 'pg_internal', 'pg_automv')
                ORDER BY table_schema, table_name
                """)
        case .vertica:
            SQLStatement(sql: """
                SELECT table_schema, table_name, 'r' FROM v_catalog.tables WHERE NOT is_system_table
                UNION ALL
                SELECT table_schema, table_name, 'v' FROM v_catalog.views WHERE NOT is_system_view
                ORDER BY 1, 2
                """)
        }
    }

    /// Primary-key columns in key order, from `information_schema` (shared by the flavors).
    static func primaryKey(of object: DatabaseObject) -> SQLStatement {
        SQLStatement(
            sql: """
                SELECT CAST(kcu.column_name AS text)
                FROM information_schema.table_constraints tc
                JOIN information_schema.key_column_usage kcu
                  ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema AND kcu.table_name = tc.table_name
                WHERE tc.constraint_type = 'PRIMARY KEY' AND tc.table_schema = $1 AND tc.table_name = $2
                ORDER BY kcu.ordinal_position
                """,
            bindings: [object.schema, object.name]
        )
    }

    static func columns(of object: DatabaseObject, flavor: PostgresFlavor) -> SQLStatement {
        let bindings = [object.schema, object.name]
        switch flavor {
        case .postgres, .greenplum:
            return SQLStatement(
                sql: """
                    SELECT a.attname::text, pg_catalog.format_type(a.atttypid, a.atttypmod)
                    FROM pg_catalog.pg_attribute a
                    JOIN pg_catalog.pg_class c ON c.oid = a.attrelid
                    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                    WHERE n.nspname = $1 AND c.relname = $2 AND a.attnum > 0 AND NOT a.attisdropped
                    ORDER BY a.attnum
                    """,
                bindings: bindings
            )
        case .cockroach, .redshift:
            return SQLStatement(
                sql: """
                    SELECT column_name::text, data_type::text
                    FROM information_schema.columns
                    WHERE table_schema = $1 AND table_name = $2
                    ORDER BY ordinal_position
                    """,
                bindings: bindings
            )
        case .vertica:
            return SQLStatement(
                sql: """
                    SELECT column_name, data_type, ordinal_position FROM v_catalog.columns WHERE table_schema = ? AND table_name = ?
                    UNION ALL
                    SELECT column_name, data_type, ordinal_position FROM v_catalog.view_columns WHERE table_schema = ? AND table_name = ?
                    ORDER BY 3
                    """,
                bindings: bindings + bindings
            )
        }
    }

    /// information_schema reports pseudo-types that cannot be used in a CAST.
    static func castableType(_ dataType: String) -> String {
        ["ARRAY", "USER-DEFINED"].contains(dataType.uppercased()) ? "" : dataType
    }
}
