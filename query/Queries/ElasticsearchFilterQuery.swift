import Foundation

/// Translates filter rules into an Elasticsearch `bool` query.
///
/// Text fields with a `.keyword` sub-field use it for exact, prefix and wildcard matching.
nonisolated struct ElasticsearchFilterQuery {
    let rules: [FilterRule]
    let columns: [ColumnInfo]

    func query() -> [String: Any] {
        var must: [[String: Any]] = []
        var mustNot: [[String: Any]] = []
        for rule in rules where rule.isActive {
            if let name = rule.column {
                guard let column = columns.first(where: { $0.name == name }) else { continue }
                let (clause, negated) = Self.clause(rule.filterOperator, column: column, value: rule.value)
                guard let clause else { continue }
                if negated { mustNot.append(clause) } else { must.append(clause) }
            } else {
                let positive = rule.filterOperator.positive
                let should = columns
                    .filter { $0.name != "_id" && Self.accepts($0, positive, value: rule.value) }
                    .compactMap { Self.clause(positive, column: $0, value: rule.value).0 }
                guard !should.isEmpty else { continue }
                let any: [String: Any] = ["bool": ["should": should, "minimum_should_match": 1]]
                if rule.filterOperator.isNegated { mustNot.append(any) } else { must.append(any) }
            }
        }
        if must.isEmpty && mustNot.isEmpty { return ["match_all": [String: Any]()] }
        var bool: [String: Any] = [:]
        if !must.isEmpty { bool["filter"] = must }
        if !mustNot.isEmpty { bool["must_not"] = mustNot }
        return ["bool": bool]
    }

    /// Returns the positive clause and whether it must be negated.
    static func clause(_ filterOperator: FilterOperator, column: ColumnInfo, value: String) -> ([String: Any]?, Bool) {
        let field = exactField(column)
        let wildcardValue = value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "*", with: "\\*").replacingOccurrences(of: "?", with: "\\?")
        func wildcard(_ pattern: String) -> [String: Any] {
            ["wildcard": [field: ["value": pattern, "case_insensitive": true]]]
        }
        func range(_ key: String) -> [String: Any] { ["range": [column.name: [key: value]]] }
        switch filterOperator {
        case .isNull: return (["exists": ["field": column.name]], true)
        case .isNotNull: return (["exists": ["field": column.name]], false)
        case .equals: return (["term": [field: value]], false)
        case .notEquals: return (["term": [field: value]], true)
        case .contains: return (wildcard("*\(wildcardValue)*"), false)
        case .notContains: return (wildcard("*\(wildcardValue)*"), true)
        case .beginsWith: return (wildcard("\(wildcardValue)*"), false)
        case .endsWith: return (wildcard("*\(wildcardValue)"), false)
        case .inList, .notInList:
            let items = value.commaSeparatedItems
            guard !items.isEmpty else { return (nil, false) }
            return (["terms": [field: items]], filterOperator == .notInList)
        case .lessThan: return (range("lt"), false)
        case .greaterThan: return (range("gt"), false)
        case .lessThanOrEqual: return (range("lte"), false)
        case .greaterThanOrEqual: return (range("gte"), false)
        }
    }

    private static let stringTypes: Set<String> = ["keyword", "text", "text+keyword", "constant_keyword", "wildcard", "match_only_text"]
    private static let numericTypes: Set<String> = [
        "long", "integer", "short", "byte", "double", "float", "half_float", "scaled_float", "unsigned_long",
    ]

    /// Whether an "Any column" clause can target `column` without Elasticsearch rejecting the
    /// whole query (e.g. `term` with "GB" on a date or number field is a parse error).
    static func accepts(_ column: ColumnInfo, _ filterOperator: FilterOperator, value: String) -> Bool {
        if filterOperator == .isNull { return true }
        if stringTypes.contains(column.dataType) { return true }
        guard ![.contains, .beginsWith, .endsWith].contains(filterOperator) else { return false }
        let items = filterOperator == .inList ? value.commaSeparatedItems : [value]
        if numericTypes.contains(column.dataType) { return items.allSatisfy { Double($0) != nil } }
        if column.dataType == "boolean" { return items.allSatisfy { $0 == "true" || $0 == "false" } }
        return false
    }

    /// `text` fields carry `+keyword` in their type when a keyword sub-field exists.
    static func exactField(_ column: ColumnInfo) -> String {
        column.dataType.hasSuffix("+keyword") ? "\(column.name).keyword" : column.name
    }
}
