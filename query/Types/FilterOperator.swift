import Foundation

/// Row-filter operators, modelled on TablePlus's filter bar.
nonisolated enum FilterOperator: String, CaseIterable, Identifiable, Hashable, Sendable {
    case equals
    case notEquals
    case lessThan
    case greaterThan
    case lessThanOrEqual
    case greaterThanOrEqual
    case contains
    case notContains
    case beginsWith
    case endsWith
    case inList
    case notInList
    case isNull
    case isNotNull

    var id: String { rawValue }

    var requiresValue: Bool {
        self != .isNull && self != .isNotNull
    }

    /// Negated operators are evaluated as `NOT (positive)` when applied to every column.
    var isNegated: Bool {
        switch self {
        case .notEquals, .notContains, .notInList, .isNotNull: true
        default: false
        }
    }

    /// The non-negated counterpart (`notContains` → `contains`); identity for the rest.
    var positive: FilterOperator {
        switch self {
        case .notEquals: .equals
        case .notContains: .contains
        case .notInList: .inList
        case .isNotNull: .isNull
        default: self
        }
    }

    /// SQL comparison operator for the comparison cases.
    var comparisonSQL: String? {
        switch self {
        case .equals: "="
        case .notEquals: "<>"
        case .lessThan: "<"
        case .greaterThan: ">"
        case .lessThanOrEqual: "<="
        case .greaterThanOrEqual: ">="
        default: nil
        }
    }
}
