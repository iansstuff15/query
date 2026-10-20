import Foundation

/// In-memory evaluation of filter rules with the same semantics as `RowFilterQuery`.
/// Used by `StubDatabaseClient` so UI tests and previews filter deterministically.
nonisolated struct RowFilterEvaluator: Sendable {
    let columns: [ColumnInfo]
    let rules: [FilterRule]

    func matches(_ values: [String?]) -> Bool {
        rules.filter(\.isActive).allSatisfy { matches($0, values) }
    }

    private func matches(_ rule: FilterRule, _ values: [String?]) -> Bool {
        if let name = rule.column {
            guard let index = columns.firstIndex(where: { $0.name == name }), values.indices.contains(index) else {
                return true
            }
            return evaluate(rule.filterOperator, values[index], rule.value)
        }
        let positive = rule.filterOperator.positive
        let anyMatches = values.contains { value in
            positive == .isNull ? value == nil : evaluate(positive, value ?? "", rule.value)
        }
        return rule.filterOperator.isNegated ? !anyMatches : anyMatches
    }

    private func evaluate(_ filterOperator: FilterOperator, _ value: String?, _ operand: String) -> Bool {
        switch filterOperator {
        case .isNull: return value == nil
        case .isNotNull: return value != nil
        default: break
        }
        guard let value else { return false }
        switch filterOperator {
        case .contains: return value.range(of: operand, options: .caseInsensitive) != nil
        case .notContains: return value.range(of: operand, options: .caseInsensitive) == nil
        case .beginsWith: return value.lowercased().hasPrefix(operand.lowercased())
        case .endsWith: return value.lowercased().hasSuffix(operand.lowercased())
        case .inList: return operand.commaSeparatedItems.contains { compare(value, $0) == .orderedSame }
        case .notInList: return !operand.commaSeparatedItems.contains { compare(value, $0) == .orderedSame }
        case .equals: return compare(value, operand) == .orderedSame
        case .notEquals: return compare(value, operand) != .orderedSame
        case .lessThan: return compare(value, operand) == .orderedAscending
        case .greaterThan: return compare(value, operand) == .orderedDescending
        case .lessThanOrEqual: return compare(value, operand) != .orderedDescending
        case .greaterThanOrEqual: return compare(value, operand) != .orderedAscending
        case .isNull, .isNotNull: return false
        }
    }

    /// Numeric comparison when both sides are numbers, otherwise text comparison.
    private func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        if let left = Double(lhs), let right = Double(rhs) {
            return left == right ? .orderedSame : (left < right ? .orderedAscending : .orderedDescending)
        }
        return lhs.compare(rhs)
    }
}
