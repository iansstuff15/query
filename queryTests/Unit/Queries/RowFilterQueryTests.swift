import Testing
@testable import query

@Suite("RowFilterQuery — PostgreSQL dialect")
struct RowFilterQueryTests {
    private let columns = [
        ColumnInfo(name: "id", dataType: "integer"),
        ColumnInfo(name: "email", dataType: "character varying(255)"),
    ]
    private let select = #"SELECT CAST("id" AS text), CAST("email" AS text) FROM "public"."customers""#

    private func statement(_ rules: [FilterRule], columns: [ColumnInfo]? = nil, limit: Int = 300) -> SQLStatement {
        RowFilterQuery(object: Fixtures.customers, columns: columns ?? self.columns, rules: rules, limit: limit).statement()
    }

    @Test func noRulesSelectsAllColumnsAsText() {
        let result = statement([])
        #expect(result.sql == "\(select) LIMIT 300")
        #expect(result.bindings.isEmpty)
    }

    @Test func noColumnsSelectsStar() {
        #expect(statement([], columns: []).sql == #"SELECT * FROM "public"."customers" LIMIT 300"#)
    }

    @Test(arguments: [
        (FilterOperator.contains, #"CAST("email" AS text) ILIKE $1"#, "%ada%"),
        (.notContains, #"CAST("email" AS text) NOT ILIKE $1"#, "%ada%"),
        (.beginsWith, #"CAST("email" AS text) ILIKE $1"#, "ada%"),
        (.endsWith, #"CAST("email" AS text) ILIKE $1"#, "%ada"),
        (.equals, #""email" = CAST($1 AS character varying(255))"#, "ada"),
        (.notEquals, #""email" <> CAST($1 AS character varying(255))"#, "ada"),
    ])
    func textColumnOperators(filterOperator: FilterOperator, condition: String, binding: String) {
        let result = statement([FilterRule(column: "email", filterOperator: filterOperator, value: "ada")])
        #expect(result.sql == "\(select) WHERE \(condition) LIMIT 300")
        #expect(result.bindings == [binding])
    }

    @Test(arguments: [(FilterOperator.lessThan, "<"), (.greaterThan, ">"), (.lessThanOrEqual, "<="), (.greaterThanOrEqual, ">=")])
    func comparisonsCastBindingToColumnType(filterOperator: FilterOperator, symbol: String) {
        let result = statement([FilterRule(column: "id", filterOperator: filterOperator, value: "10")])
        #expect(result.sql.contains(#"WHERE "id" \#(symbol) CAST($1 AS integer)"#))
        #expect(result.bindings == ["10"])
    }

    @Test func nullChecksNeedNoBindings() {
        let result = statement([FilterRule(column: "email", filterOperator: .isNull), FilterRule(column: "id", filterOperator: .isNotNull)])
        #expect(result.sql.contains(#"WHERE "email" IS NULL AND "id" IS NOT NULL"#))
        #expect(result.bindings.isEmpty)
    }

    @Test func inListBindsEachItem() {
        let result = statement([FilterRule(column: "id", filterOperator: .inList, value: "1, 2 ,3")])
        #expect(result.sql.contains(#""id" IN (CAST($1 AS integer), CAST($2 AS integer), CAST($3 AS integer))"#))
        #expect(result.bindings == ["1", "2", "3"])
    }

    @Test func notInListAndEmptyListIsIgnored() {
        #expect(statement([FilterRule(column: "id", filterOperator: .notInList, value: "4")]).sql.contains(#""id" NOT IN (CAST($1 AS integer))"#))
        #expect(statement([FilterRule(column: "id", filterOperator: .inList, value: " , ")]).sql == "\(select) LIMIT 300")
    }

    @Test func anyColumnOrsAcrossColumnsReusingOneBinding() {
        let result = statement([FilterRule(column: nil, filterOperator: .contains, value: "ada")])
        #expect(result.sql == "\(select) WHERE (COALESCE(CAST(\"id\" AS text), '') ILIKE $1 OR COALESCE(CAST(\"email\" AS text), '') ILIKE $1) LIMIT 300")
        #expect(result.bindings == ["%ada%"])
    }

    @Test func anyColumnNegationWrapsInNot() {
        #expect(statement([FilterRule(column: nil, filterOperator: .notEquals, value: "x")]).sql.contains("WHERE NOT (COALESCE("))
    }

    @Test func anyColumnIsNullAndInList() {
        #expect(statement([FilterRule(column: nil, filterOperator: .isNotNull)]).sql.contains(#"WHERE NOT ("id" IS NULL OR "email" IS NULL)"#))
        let list = statement([FilterRule(column: nil, filterOperator: .inList, value: "a,b")])
        #expect(list.sql.contains("COALESCE(CAST(\"id\" AS text), '') IN ($1, $2)"))
        #expect(list.bindings == ["a", "b"])
    }

    @Test func multipleRulesAreAndedWithSequentialPlaceholders() {
        let result = statement([
            FilterRule(column: "id", filterOperator: .greaterThan, value: "1"),
            FilterRule(column: "email", filterOperator: .contains, value: "x"),
        ])
        #expect(result.sql.contains(#"WHERE "id" > CAST($1 AS integer) AND CAST("email" AS text) ILIKE $2"#))
        #expect(result.bindings == ["1", "%x%"])
    }

    @Test func inactiveAndUnknownRulesAreSkipped() {
        let result = statement([
            FilterRule(column: "email", filterOperator: .contains, value: "x", isEnabled: false),
            FilterRule(column: "email", filterOperator: .contains, value: ""),
            FilterRule(column: "nope", filterOperator: .equals, value: "x"),
        ])
        #expect(result.sql == "\(select) LIMIT 300")
    }

    @Test func userValuesNeverAppearInSQL() {
        let payload = "'; DROP TABLE customers; --"
        let result = statement([FilterRule(column: nil, filterOperator: .equals, value: payload)])
        #expect(!result.sql.contains("DROP"))
        #expect(result.bindings == [payload])
    }

    @Test func identifiersAreQuoted() {
        let object = DatabaseObject(schema: #"my"schema"#, name: "t", kind: .table)
        let result = RowFilterQuery(object: object, columns: [ColumnInfo(name: #"we"ird"#, dataType: "text")], rules: [], limit: 1).statement()
        #expect(result.sql == #"SELECT CAST("we""ird" AS text) FROM "my""schema"."t" LIMIT 1"#)
    }

    @Test func likeWildcardsInValuesAreEscaped() {
        let result = statement([FilterRule(column: "email", filterOperator: .contains, value: #"50%_off\"#)])
        #expect(result.bindings == [#"%50\%\_off\\%"#])
    }

    @Test func unsafeTypeNameFallsBackToTextComparison() {
        let result = statement([FilterRule(column: "x", filterOperator: .equals, value: "1")], columns: [ColumnInfo(name: "x", dataType: "int; DROP TABLE t")])
        #expect(result.sql.contains(#"WHERE CAST("x" AS text) = $1"#))
        #expect(!result.sql.contains("DROP"))
    }

    @Test func negativeLimitClampsToZero() {
        #expect(statement([], limit: -5).sql.hasSuffix("LIMIT 0"))
    }
}
