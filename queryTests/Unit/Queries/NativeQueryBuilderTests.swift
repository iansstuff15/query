import Foundation
import Testing
@testable import query

@Suite("Native query builders")
struct NativeQueryBuilderTests {
    // MARK: MongoDB

    @Test func mongoEmptyRulesMatchEverything() {
        #expect(BSONText.text(MongoFilterQuery(rules: [], fields: ["a"]).document()) == "{}")
    }

    @Test func mongoTextOperatorsUseEscapedCaseInsensitiveRegex() throws {
        let filter = MongoFilterQuery(rules: [FilterRule(column: "email", filterOperator: .beginsWith, value: "a.b")], fields: []).document()
        let text = try #require(BSONText.text(filter))
        #expect(text.contains(#"^a\\.b"#))
        #expect(text.contains("\"$options\"") || text.contains("options"))
    }

    @Test func mongoEqualsMatchesStringAndNumber() throws {
        let filter = MongoFilterQuery(rules: [FilterRule(column: "id", filterOperator: .equals, value: "7")], fields: []).document()
        #expect(BSONText.text(filter) == #"{"id":{"$in":["7",7]}}"#)
    }

    @Test func mongoAnyColumnNegationUsesNor() throws {
        let filter = MongoFilterQuery(rules: [FilterRule(column: nil, filterOperator: .isNotNull)], fields: ["a", "b"]).document()
        #expect(BSONText.text(filter) == #"{"$nor":[{"$or":[{"a":null},{"b":null}]}]}"#)
    }

    @Test func mongoMultipleRulesUseAnd() {
        let rules = [FilterRule(column: "a", filterOperator: .greaterThan, value: "1"), FilterRule(column: "b", filterOperator: .isNull)]
        #expect(BSONText.text(MongoFilterQuery(rules: rules, fields: []).document()) == #"{"$and":[{"a":{"$gt":1}},{"b":null}]}"#)
    }

    // MARK: Elasticsearch

    private let esColumns = [ColumnInfo(name: "_id", dataType: "keyword"), ColumnInfo(name: "full_name", dataType: "text+keyword"), ColumnInfo(name: "total", dataType: "scaled_float")]

    @Test func elasticsearchMatchAllWithoutRules() {
        #expect(JSONText.text(ElasticsearchFilterQuery(rules: [], columns: esColumns).query()) == #"{"match_all":{}}"#)
    }

    @Test func elasticsearchUsesKeywordSubfieldAndRanges() throws {
        let rules = [
            FilterRule(column: "full_name", filterOperator: .contains, value: "a*b"),
            FilterRule(column: "total", filterOperator: .greaterThanOrEqual, value: "10"),
            FilterRule(column: "full_name", filterOperator: .isNull),
        ]
        let text = try #require(JSONText.text(ElasticsearchFilterQuery(rules: rules, columns: esColumns).query()))
        #expect(text.contains(#""wildcard":{"full_name.keyword":{"case_insensitive":true,"value":"*a\\*b*"}}"#))
        #expect(text.contains(#"{"range":{"total":{"gte":"10"}}}"#))
        #expect(text.contains(#""must_not":[{"exists":{"field":"full_name"}}]"#))
    }

    @Test func elasticsearchAnyColumnSkipsIncompatibleFields() throws {
        let columns = esColumns + [ColumnInfo(name: "created_at", dataType: "date")]
        let text = try #require(JSONText.text(ElasticsearchFilterQuery(rules: [FilterRule(column: nil, filterOperator: .equals, value: "GB")], columns: columns).query()))
        #expect(text.contains("full_name.keyword"))
        #expect(!text.contains("created_at"))
        #expect(!text.contains("\"total\""))
        let numeric = try #require(JSONText.text(ElasticsearchFilterQuery(rules: [FilterRule(column: nil, filterOperator: .equals, value: "12.5")], columns: columns).query()))
        #expect(numeric.contains("\"total\""))
        #expect(ElasticsearchFilterQuery.accepts(columns[2], .contains, value: "1") == false)
    }

    @Test func elasticsearchFlattensNestedMappings() {
        let columns = ElasticsearchDatabaseClient.flatten(
            ["address": ["properties": ["city": ["type": "keyword"]]], "name": ["type": "text", "fields": ["keyword": ["type": "keyword"]]]],
            prefix: ""
        )
        #expect(columns == [ColumnInfo(name: "address.city", dataType: "keyword"), ColumnInfo(name: "name", dataType: "text+keyword")])
        #expect(ElasticsearchDatabaseClient.value(at: "address.city", in: ["address": ["city": "Paris"]]) as? String == "Paris")
    }

    // MARK: DynamoDB

    @Test func dynamoBuildsTypedFilterExpressionAndSkipsTextOperators() {
        let rules = [
            FilterRule(column: "id", filterOperator: .greaterThan, value: "10"),
            FilterRule(column: "status", filterOperator: .inList, value: "paid,shipped"),
            FilterRule(column: "email", filterOperator: .contains, value: "x"),
        ]
        let expression = DynamoDBFilterQuery(rules: rules, attributeTypes: ["id": "N", "status": "S"]).expression()
        #expect(expression.filter == "#a0 > :v0 AND #a1 IN (:v1, :v2)")
        #expect(expression.names == ["#a0": "id", "#a1": "status"])
        #expect(expression.values[":v0"] as? [String: String] == ["N": "10"])
        #expect(expression.values[":v2"] as? [String: String] == ["S": "shipped"])
    }

    @Test func dynamoRendersAttributeValues() {
        #expect(DynamoDBDatabaseClient.text(["S": "a"]) == "a")
        #expect(DynamoDBDatabaseClient.text(["N": "1.5"]) == "1.5")
        #expect(DynamoDBDatabaseClient.text(["NULL": true]) == nil)
        #expect(DynamoDBDatabaseClient.text(["BOOL": true]) == "true")
        #expect(DynamoDBDatabaseClient.text(["M": ["a": ["N": "1"]]]) == #"{"a":1}"#)
    }

    // MARK: Cassandra

    @Test func cqlRunsTypedEqualityServerSideAndTheRestClientSide() {
        let columns = [ColumnInfo(name: "id", dataType: "int"), ColumnInfo(name: "tags", dataType: "set<text>")]
        let rules = [FilterRule(column: "id", filterOperator: .equals, value: "7"), FilterRule(column: "id", filterOperator: .greaterThan, value: "1")]
        let plan = CQLFilterQuery(object: Fixtures.customers, columns: columns, rules: rules, limit: 10).plan()
        #expect(plan.cql == #"SELECT CAST("id" AS text) AS "id", toJson("tags") AS "tags" FROM "public"."customers" WHERE "id" = ? LIMIT 5000 ALLOW FILTERING"#)
        #expect(plan.bindings == [.int32(7)])
        #expect(plan.clientRules.count == 1)
    }

    @Test func cqlValueParsing() {
        #expect(CQLValue("x", cqlType: "text") == .text("x"))
        #expect(CQLValue("9", cqlType: "bigint") == .int64(9))
        #expect(CQLValue("abc", cqlType: "int") == nil)
        #expect(CQLValue("TRUE", cqlType: "boolean") == .bool(true))
        #expect(CQLValue("1", cqlType: "uuid") == nil)
    }

    // MARK: Redis

    @Test(arguments: [
        (FilterOperator.beginsWith, "customer:", "customer:*"),
        (.contains, "a*b", "*a\\*b*"),
        (.equals, "x?", "x\\?"),
        (.lessThan, "1", "*"),
    ])
    func redisMatchPattern(filterOperator: FilterOperator, value: String, pattern: String) {
        #expect(RedisDatabaseClient.matchPattern(for: [FilterRule(column: "key", filterOperator: filterOperator, value: value)]) == pattern)
    }

    @Test func redisKeyspaceParsingHandlesCRLF() {
        let info = "# Keyspace\r\ndb0:keys=39,expires=1,avg_ttl=1\r\ndb12:keys=1,expires=0,avg_ttl=0\r\n"
        #expect(RedisDatabaseClient.keyspaceDatabases(fromInfo: info) == [0, 12])
    }

    @Test func respEncoding() {
        #expect(String(decoding: RESPConnection.encode(["SET", "k", "é"]), as: UTF8.self) == "*3\r\n$3\r\nSET\r\n$1\r\nk\r\n$2\r\né\r\n")
    }
}
