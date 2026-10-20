import Foundation

/// Turns filter-bar rules into a parameterized `SELECT … WHERE … LIMIT` for any SQL engine —
/// the server-side half of TablePlus-style search. User values only travel as bindings.
///
/// - Rules are combined with `AND`.
/// - Comparisons pass the column type to the dialect so values compare natively
///   (`CAST($1 AS integer)`, `{p1:Int32}`); text operators use case-insensitive `LIKE`.
/// - "Any column" ORs the positive operator across all columns; negated operators wrap it
///   in `NOT (…)`, i.e. "no column matches".
nonisolated struct RowFilterQuery: Sendable {
    let object: DatabaseObject
    let columns: [ColumnInfo]
    let rules: [FilterRule]
    let limit: Int
    let dialect: any SQLDialect

    init(object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int, dialect: any SQLDialect = PostgresDialect.postgres) {
        self.object = object
        self.columns = columns
        self.rules = rules
        self.limit = limit
        self.dialect = dialect
    }

    func statement() -> SQLStatement {
        var builder = Builder(dialect: dialect)
        let selectList = columns.isEmpty
            ? "*"
            // No aliases: ClickHouse resolves WHERE names against SELECT aliases, and the grid
            // takes column names from catalog metadata anyway.
            : columns.map { dialect.text(dialect.quote($0.name)) }.joined(separator: ", ")
        let conditions = rules.filter(\.isActive).compactMap { rule -> String? in
            if let name = rule.column {
                guard let column = columns.first(where: { $0.name == name }) else { return nil }
                return builder.condition(rule, column: column)
            }
            return builder.anyColumnCondition(rule, columns: columns)
        }
        let sql = dialect.select(
            selectList,
            from: dialect.table(object),
            where: conditions.isEmpty ? nil : conditions.joined(separator: " AND "),
            limit: max(limit, 0)
        )
        return SQLStatement(sql: sql, bindings: builder.bindings)
    }
}

private nonisolated struct Builder {
    let dialect: any SQLDialect
    private(set) var bindings: [String] = []

    init(dialect: any SQLDialect) {
        self.dialect = dialect
    }

    /// Appends `value` and returns its marker.
    mutating func bind(_ value: String, columnType: String? = nil) -> String {
        bindings.append(value)
        return dialect.parameter(bindings.count, columnType: columnType)
    }

    mutating func condition(_ rule: FilterRule, column: ColumnInfo) -> String? {
        let quoted = dialect.quote(column.name)
        let asText = dialect.text(quoted)
        let value = rule.value
        let isTyped = column.dataType.isSafeSQLTypeName
        let lhs = isTyped ? quoted : asText
        let type = isTyped ? column.dataType : nil
        switch rule.filterOperator {
        case .isNull:
            return "\(quoted) IS NULL"
        case .isNotNull:
            return "\(quoted) IS NOT NULL"
        case .contains, .notContains, .beginsWith, .endsWith:
            let marker = bind(pattern(for: rule.filterOperator, value))
            return dialect.like(asText, marker, negated: rule.filterOperator == .notContains)
        case .inList, .notInList:
            let items = value.commaSeparatedItems
            guard !items.isEmpty else { return nil }
            let markers = items.map { bind($0, columnType: type) }.joined(separator: ", ")
            return "\(lhs) \(rule.filterOperator == .inList ? "IN" : "NOT IN") (\(markers))"
        case .equals, .notEquals, .lessThan, .greaterThan, .lessThanOrEqual, .greaterThanOrEqual:
            guard let sqlOperator = rule.filterOperator.comparisonSQL else { return nil }
            return "\(lhs) \(sqlOperator) \(bind(value, columnType: type))"
        }
    }

    mutating func anyColumnCondition(_ rule: FilterRule, columns: [ColumnInfo]) -> String? {
        guard !columns.isEmpty else { return nil }
        let positive = rule.filterOperator.positive
        let items = rule.value.commaSeparatedItems
        if positive == .inList, items.isEmpty { return nil }

        // Numbered dialects bind once and reuse the marker; positional ones bind per column.
        var shared: [String]?
        let predicates = columns.map { column -> String in
            let expression = dialect.coalesceEmpty(dialect.text(dialect.quote(column.name)))
            switch positive {
            case .isNull:
                return "\(dialect.quote(column.name)) IS NULL"
            case .inList:
                let markers = markers(for: items, shared: &shared)
                return "\(expression) IN (\(markers.joined(separator: ", ")))"
            case .contains, .beginsWith, .endsWith:
                let marker = markers(for: [pattern(for: positive, rule.value)], shared: &shared)[0]
                return dialect.like(expression, marker, negated: false)
            default:
                let marker = markers(for: [rule.value], shared: &shared)[0]
                return "\(expression) \(positive.comparisonSQL ?? "=") \(marker)"
            }
        }
        let any = "(" + predicates.joined(separator: " OR ") + ")"
        return rule.filterOperator.isNegated ? "NOT \(any)" : any
    }

    private mutating func markers(for values: [String], shared: inout [String]?) -> [String] {
        if dialect.reusesParameters, let shared { return shared }
        let markers = values.map { bind($0) }
        if dialect.reusesParameters { shared = markers }
        return markers
    }

    private func pattern(for filterOperator: FilterOperator, _ value: String) -> String {
        let escaped = value.escapedLikePattern
        switch filterOperator {
        case .beginsWith: return "\(escaped)%"
        case .endsWith: return "%\(escaped)"
        default: return "%\(escaped)%"
        }
    }
}
