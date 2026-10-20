import Testing
@testable import query

@Suite("Types")
struct TypesTests {
    @Test(arguments: [("r", DatabaseObjectKind.table), ("p", .partitionedTable), ("v", .view), ("m", .materializedView), ("f", .foreignTable)])
    func relkindMapping(relkind: String, kind: DatabaseObjectKind) {
        #expect(DatabaseObjectKind(relkind: relkind) == kind)
    }

    @Test func unknownRelkindIsNil() {
        #expect(DatabaseObjectKind(relkind: "S") == nil)
    }

    @Test(arguments: FilterOperator.allCases)
    func positiveIsNeverNegated(filterOperator: FilterOperator) {
        #expect(!filterOperator.positive.isNegated)
        #expect(filterOperator.isNegated == (filterOperator.positive != filterOperator))
    }

    @Test func requiresValueOnlyForValueOperators() {
        #expect(!FilterOperator.isNull.requiresValue)
        #expect(!FilterOperator.isNotNull.requiresValue)
        #expect(FilterOperator.contains.requiresValue)
    }

    @Test func filterRuleIsActive() {
        #expect(FilterRule(filterOperator: .contains, value: "a").isActive)
        #expect(!FilterRule(filterOperator: .contains, value: "").isActive)
        #expect(FilterRule(filterOperator: .isNull).isActive)
        #expect(!FilterRule(filterOperator: .isNull, isEnabled: false).isActive)
    }

    @Test func serverEndpointFromDraftAppliesDefaults() throws {
        let endpoint = try ServerEndpoint(draft: ConnectionDraft(engine: .mySQL, values: [.host: " db ", .username: "me"]))
        #expect(endpoint.host == "db")
        #expect(endpoint.port == 3_306)
        #expect(endpoint.tlsMode == .prefer)
        #expect(throws: DatabaseError.missingConfiguration) {
            try ServerEndpoint(draft: ConnectionDraft(engine: .mySQL, values: [.host: "db", .port: "0"]))
        }
        let oracle = try ServerEndpoint(draft: ConnectionDraft(engine: .oracle, values: [.host: "db", .serviceName: "FREEPDB1"]))
        #expect(oracle.database == "FREEPDB1")
    }

    @Test func queryResultIndexesColumns() {
        let result = QueryResult(columns: [Fixtures.intColumn, Fixtures.textColumn], values: [["1", nil]])
        #expect(result.columns.map(\.id) == [0, 1])
        #expect(result.rows.first?[result.columns[0]] == "1")
        #expect(result.rows.first?[result.columns[1]] == nil)
        #expect(result.rows.first?[ResultColumn(id: 9, name: "x")] == nil)
        #expect(!result.isEmpty)
    }

    @Test func loadStateAccessors() {
        #expect(LoadState<Int>.loaded(3).value == 3)
        #expect(LoadState<Int>.loading.isLoading)
        #expect(LoadState<Int>.failed(MockError()).value == nil)
        #expect(!LoadState<Int>.idle.isLoading)
    }
}
