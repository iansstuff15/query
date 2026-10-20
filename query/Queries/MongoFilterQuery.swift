import Foundation
import MongoKitten

/// Translates filter rules into a MongoDB query document.
///
/// Text operators become case-insensitive anchored regexes; comparisons match both the
/// typed (number / bool / ObjectId) and string forms of the value, since documents are
/// schemaless. "Any column" ORs the rule across `fields`.
nonisolated struct MongoFilterQuery {
    let rules: [FilterRule]
    let fields: [String]

    func document() -> Document {
        let clauses = rules.filter(\.isActive).compactMap { rule -> Document? in
            if let field = rule.column { return Self.clause(field: field, rule: rule) }
            guard !fields.isEmpty else { return nil }
            var positive = rule
            positive.filterOperator = rule.filterOperator.positive
            let alternatives = fields.compactMap { Self.clause(field: $0, rule: positive) }
            let any: Document = ["$or": Self.array(alternatives)]
            return rule.filterOperator.isNegated ? ["$nor": Self.array([any])] : any
        }
        switch clauses.count {
        case 0: return [:]
        case 1: return clauses[0]
        default: return ["$and": Self.array(clauses)]
        }
    }

    static func clause(field: String, rule: FilterRule) -> Document? {
        let value = rule.value
        switch rule.filterOperator {
        case .isNull: return [field: Null()]
        case .isNotNull: return [field: ["$ne": Null()] as Document]
        case .contains: return [field: regex("\(NSRegularExpression.escapedPattern(for: value))")]
        case .notContains: return [field: ["$not": regex(NSRegularExpression.escapedPattern(for: value))] as Document]
        case .beginsWith: return [field: regex("^\(NSRegularExpression.escapedPattern(for: value))")]
        case .endsWith: return [field: regex("\(NSRegularExpression.escapedPattern(for: value))$")]
        case .equals: return [field: ["$in": array(candidates(value, field: field))] as Document]
        case .notEquals: return [field: ["$nin": array(candidates(value, field: field))] as Document]
        case .inList, .notInList:
            let items = value.commaSeparatedItems.flatMap { candidates($0, field: field) }
            guard !items.isEmpty else { return nil }
            return [field: [rule.filterOperator == .inList ? "$in" : "$nin": array(items)] as Document]
        case .lessThan, .greaterThan, .lessThanOrEqual, .greaterThanOrEqual:
            let key = switch rule.filterOperator {
            case .lessThan: "$lt"
            case .greaterThan: "$gt"
            case .lessThanOrEqual: "$lte"
            default: "$gte"
            }
            return [field: [key: typed(value)] as Document]
        }
    }

    /// The string plus any typed interpretations of `value`.
    static func candidates(_ value: String, field: String) -> [Primitive] {
        var result: [Primitive] = [value]
        if let int = Int(value) { result.append(int) }
        if let double = Double(value), Int(value) == nil { result.append(double) }
        if value == "true" || value == "false" { result.append(value == "true") }
        if value.count == 24, let objectID = ObjectId(value) { result.append(objectID) }
        return result
    }

    static func typed(_ value: String) -> Primitive {
        if let int = Int(value) { return int }
        if let double = Double(value) { return double }
        return value
    }

    private static func regex(_ pattern: String) -> RegularExpression {
        RegularExpression(pattern: pattern, options: "i")
    }

    private static func array(_ values: [Primitive]) -> Document {
        var document = Document(isArray: true)
        values.forEach { document.append($0) }
        return document
    }
}
