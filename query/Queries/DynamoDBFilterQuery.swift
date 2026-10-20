import Foundation

/// Builds a DynamoDB Scan `FilterExpression` for the rules DynamoDB evaluates natively.
///
/// Comparisons, `IN` and existence checks run server-side. Text operators are left to the
/// client-side evaluator, because DynamoDB's `contains`/`begins_with` are case-sensitive.
nonisolated struct DynamoDBFilterQuery {
    let rules: [FilterRule]
    /// Attribute name → DynamoDB scalar type (`S`, `N`, `B`, `BOOL`, …).
    let attributeTypes: [String: String]

    struct Expression {
        var filter: String?
        var names: [String: String] = [:]
        var values: [String: [String: Any]] = [:]
    }

    func expression() -> Expression {
        var expression = Expression()
        var clauses: [String] = []
        for rule in rules where rule.isActive {
            guard let field = rule.column else { continue }
            let name = "#a\(expression.names.count)"
            func value(_ raw: String) -> String {
                let key = ":v\(expression.values.count)"
                expression.values[key] = attributeTypes[field] == "N" && Double(raw) != nil ? ["N": raw] : ["S": raw]
                return key
            }
            switch rule.filterOperator {
            case .isNull:
                clauses.append("(attribute_not_exists(\(name)) OR attribute_type(\(name), :null))")
                expression.values[":null"] = ["S": "NULL"]
            case .isNotNull:
                clauses.append("attribute_exists(\(name))")
            case .equals, .notEquals, .lessThan, .greaterThan, .lessThanOrEqual, .greaterThanOrEqual:
                guard let sqlOperator = rule.filterOperator.comparisonSQL else { continue }
                clauses.append("\(name) \(sqlOperator) \(value(rule.value))")
            case .inList, .notInList:
                let items = rule.value.commaSeparatedItems
                guard !items.isEmpty else { continue }
                let list = "\(name) IN (\(items.map(value).joined(separator: ", ")))"
                clauses.append(rule.filterOperator == .inList ? list : "NOT (\(list))")
            case .contains, .notContains, .beginsWith, .endsWith:
                continue
            }
            expression.names[name] = field
        }
        expression.filter = clauses.isEmpty ? nil : clauses.joined(separator: " AND ")
        return expression
    }
}
