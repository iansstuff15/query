import Testing
@testable import query

@Suite("RowFilterEvaluator")
struct RowFilterEvaluatorTests {
    private let columns = [Fixtures.intColumn, Fixtures.textColumn]

    private func matches(_ rule: FilterRule, _ values: [String?]) -> Bool {
        RowFilterEvaluator(columns: columns, rules: [rule]).matches(values)
    }

    @Test(arguments: [
        (FilterOperator.equals, "5", true),
        (.equals, "05", true),
        (.notEquals, "5", false),
        (.lessThan, "10", true),
        (.greaterThan, "10", false),
        (.lessThanOrEqual, "5", true),
        (.greaterThanOrEqual, "6", false),
        (.inList, "1, 5, 9", true),
        (.notInList, "1, 5, 9", false),
    ])
    func numericComparisons(filterOperator: FilterOperator, value: String, expected: Bool) {
        let rule = FilterRule(column: "id", filterOperator: filterOperator, value: value)
        #expect(matches(rule, ["5", "ada@example.com"]) == expected)
    }

    @Test(arguments: [
        (FilterOperator.contains, "EXAMPLE", true),
        (.notContains, "example", false),
        (.beginsWith, "Ada", true),
        (.endsWith, ".COM", true),
        (.endsWith, ".org", false),
    ])
    func textOperatorsAreCaseInsensitive(filterOperator: FilterOperator, value: String, expected: Bool) {
        let rule = FilterRule(column: "email", filterOperator: filterOperator, value: value)
        #expect(matches(rule, ["5", "ada@example.com"]) == expected)
    }

    @Test func nullOnlyMatchesNullOperators() {
        #expect(matches(FilterRule(column: "email", filterOperator: .isNull), ["1", nil]))
        #expect(!matches(FilterRule(column: "email", filterOperator: .isNotNull), ["1", nil]))
        #expect(!matches(FilterRule(column: "email", filterOperator: .contains, value: "a"), ["1", nil]))
    }

    @Test func anyColumnMatchesWhenSomeColumnMatches() {
        let rule = FilterRule(column: nil, filterOperator: .contains, value: "example")
        #expect(matches(rule, ["5", "ada@example.com"]))
        #expect(!matches(rule, ["5", "ada@mail.test"]))
    }

    @Test func negatedAnyColumnMeansNoColumnMatches() {
        let rule = FilterRule(column: nil, filterOperator: .notContains, value: "5")
        #expect(!matches(rule, ["5", "ada@example.com"]))
        #expect(matches(rule, ["6", "ada@example.com"]))
    }

    @Test func inactiveAndUnknownColumnRulesAreIgnored() {
        let rules = [
            FilterRule(column: "email", filterOperator: .contains, value: "zzz", isEnabled: false),
            FilterRule(column: "email", filterOperator: .contains, value: ""),
            FilterRule(column: "missing", filterOperator: .equals, value: "x"),
        ]
        #expect(RowFilterEvaluator(columns: columns, rules: rules).matches(["1", "a@b.c"]))
    }

    @Test func allRulesMustMatch() {
        let rules = [
            FilterRule(column: "id", filterOperator: .greaterThan, value: "1"),
            FilterRule(column: "email", filterOperator: .contains, value: "example"),
        ]
        let evaluator = RowFilterEvaluator(columns: columns, rules: rules)
        #expect(evaluator.matches(["2", "x@example.com"]))
        #expect(!evaluator.matches(["1", "x@example.com"]))
    }
}
