import Testing
@testable import query

@Suite("RowUpdateQuery")
struct RowUpdateQueryTests {
    private let object = DatabaseObject(schema: "public", name: "customers", kind: .table)
    private let columns = [ColumnInfo(name: "id", dataType: "integer"), ColumnInfo(name: "country", dataType: "text"), ColumnInfo(name: "note", dataType: "text")]

    private func change(values: [String?], key: [String] = ["id"]) -> RowChange {
        RowChange(object: object, columns: columns, original: ["7", nil, "hi"], values: values, keyColumns: key)
    }

    @Test func updatesOnlyChangedColumnsByPrimaryKeyInPostgres() throws {
        let statement = try #require(RowUpdateQuery(change: change(values: ["7", "GB", "hi"]), dialect: PostgresDialect.postgres).statement())
        #expect(statement.sql == #"UPDATE "public"."customers" SET "country" = CAST($1 AS text) WHERE CAST("id" AS text) = $2"#)
        #expect(statement.bindings == ["GB", "7"])
    }

    @Test func castsNewValuesToTheColumnType() throws {
        let statement = try #require(RowUpdateQuery(change: change(values: ["8", nil, "hi"]), dialect: PostgresDialect.postgres).statement())
        #expect(statement.sql.hasPrefix(#"UPDATE "public"."customers" SET "id" = CAST($1 AS integer)"#))
    }

    @Test func nullsAreAssignedAndMatchedWithIsNull() throws {
        let statement = try #require(RowUpdateQuery(change: change(values: ["7", nil, nil], key: []), dialect: MySQLDialect()).statement())
        #expect(statement.sql == "UPDATE `public`.`customers` SET `note` = NULL WHERE CAST(`id` AS CHAR) = ? AND `country` IS NULL AND CAST(`note` AS CHAR) = ?")
        #expect(statement.bindings == ["7", "hi"])
    }

    @Test func anUnknownKeyColumnFallsBackToEveryColumn() throws {
        let statement = try #require(RowUpdateQuery(change: change(values: ["7", "GB", "hi"], key: ["missing"]), dialect: MySQLDialect()).statement())
        #expect(statement.sql.hasSuffix("WHERE CAST(`id` AS CHAR) = ? AND `country` IS NULL AND CAST(`note` AS CHAR) = ?"))
    }

    @Test func nothingChangedMeansNoStatement() {
        #expect(RowUpdateQuery(change: change(values: ["7", nil, "hi"]), dialect: PostgresDialect.postgres).statement() == nil)
    }

    @Test func valuesNeverAppearInTheSQL() throws {
        let statement = try #require(RowUpdateQuery(change: change(values: ["7", "'; DROP TABLE customers; --", "hi"]), dialect: PostgresDialect.postgres).statement())
        #expect(!statement.sql.contains("DROP"))
    }

    @Test func clickHouseDoesntOfferRowUpdates() {
        #expect(!ClickHouseDialect().supportsRowUpdates)
        #expect(PostgresDialect.postgres.supportsRowUpdates)
    }
}
