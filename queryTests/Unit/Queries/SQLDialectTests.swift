import Testing
@testable import query

/// The same rules rendered for each SQL dialect.
@Suite("SQL dialects")
struct SQLDialectTests {
    private let object = DatabaseObject(schema: "app", name: "customers", kind: .table)
    private let columns = [ColumnInfo(name: "id", dataType: "int"), ColumnInfo(name: "email", dataType: "varchar(255)")]
    private let anyContains = FilterRule(column: nil, filterOperator: .contains, value: "ada")
    private let idAbove = FilterRule(column: "id", filterOperator: .greaterThan, value: "10")

    private func statement(_ dialect: any SQLDialect, _ rules: [FilterRule], limit: Int = 5) -> SQLStatement {
        RowFilterQuery(object: object, columns: columns, rules: rules, limit: limit, dialect: dialect).statement()
    }

    @Test func mySQLUsesBackticksAndRebindsPositionalMarkers() {
        let result = statement(MySQLDialect(), [anyContains])
        #expect(result.sql == "SELECT CAST(`id` AS CHAR), CAST(`email` AS CHAR) FROM `app`.`customers` WHERE (LOWER(COALESCE(CAST(`id` AS CHAR), '')) LIKE LOWER(?) OR LOWER(COALESCE(CAST(`email` AS CHAR), '')) LIKE LOWER(?)) LIMIT 5")
        #expect(result.bindings == ["%ada%", "%ada%"])
        #expect(statement(MySQLDialect(), [idAbove]).sql.contains("WHERE `id` > ? LIMIT 5"))
    }

    @Test func sqlServerUsesTopBracketsAndNamedParameters() {
        let result = statement(SQLServerDialect(), [idAbove, FilterRule(column: "email", filterOperator: .beginsWith, value: "a")])
        #expect(result.sql == "SELECT TOP (5) CAST([id] AS NVARCHAR(4000)), CAST([email] AS NVARCHAR(4000)) FROM [app].[customers] WHERE [id] > @p1 AND LOWER(CAST([email] AS NVARCHAR(4000))) LIKE LOWER(@p2) ESCAPE '\\'")
        #expect(SQLServerDialect().quote("a]b") == "[a]]b]")
    }

    @Test func oracleUsesFetchFirstAndColonBinds() {
        let result = statement(OracleDialect(), [idAbove])
        #expect(result.sql == #"SELECT TO_CHAR("id"), TO_CHAR("email") FROM "app"."customers" WHERE "id" > :1 FETCH FIRST 5 ROWS ONLY"#)
        #expect(statement(OracleDialect(), [anyContains]).bindings == ["%ada%", "%ada%"])
    }

    @Test func sqliteOmitsMainSchemaAndReusesNumberedMarkers() {
        let main = DatabaseObject(schema: "main", name: "customers", kind: .table)
        let result = RowFilterQuery(object: main, columns: columns, rules: [anyContains], limit: 5, dialect: SQLiteDialect()).statement()
        #expect(result.sql.contains(#"FROM "customers" WHERE"#))
        #expect(result.sql.contains("LIKE LOWER(?1) ESCAPE"))
        #expect(result.bindings == ["%ada%"])
    }

    @Test func clickHouseUsesTypedServerParameters() {
        let result = statement(ClickHouseDialect(), [idAbove, anyContains])
        #expect(result.sql.contains("WHERE `id` > {p1:int} AND (COALESCE(toString(`id`), '') ILIKE {p2:String}"))
        #expect(result.bindings == ["10", "%ada%"])
    }

    @Test func bigQueryCastsNamedParametersToColumnType() {
        #expect(statement(BigQueryDialect(), [idAbove]).sql.contains("WHERE `id` > CAST(@p1 AS int) LIMIT 5"))
    }

    @Test func snowflakeEscapesBackslashInILike() {
        let result = statement(SnowflakeDialect(), [FilterRule(column: "email", filterOperator: .contains, value: "a")])
        #expect(result.sql.contains(#"TO_VARCHAR("email") ILIKE ? ESCAPE '\\'"#))
    }

    @Test func duckDBAndVerticaVariants() {
        #expect(statement(DuckDBDialect(), [anyContains]).sql.contains("ILIKE $1 ESCAPE"))
        let vertica = statement(PostgresDialect.vertica, [idAbove, anyContains])
        #expect(vertica.sql.contains(#""id" > CAST(? AS int)"#))
        #expect(vertica.bindings == ["10", "%ada%", "%ada%"])
        #expect(statement(PostgresDialect.redshift, []).sql.contains("varchar(65535)"))
    }
}
