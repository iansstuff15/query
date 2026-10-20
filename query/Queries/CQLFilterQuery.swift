import Foundation

/// Builds a CQL `SELECT` for Cassandra / ScyllaDB.
///
/// CQL has no `LIKE` without special indexes and only allows ranges on partition keys via
/// `token()`, so equality runs server-side (with `ALLOW FILTERING` and typed bindings) and
/// everything else is evaluated client-side over a larger scan.
nonisolated struct CQLFilterQuery {
    let object: DatabaseObject
    let columns: [ColumnInfo]
    let rules: [FilterRule]
    let limit: Int
    /// Rows fetched when some rules must be evaluated client-side.
    var clientSideScanLimit = 5_000

    struct Plan {
        let cql: String
        let bindings: [CQLValue]
        /// Rules to apply after fetching.
        let clientRules: [FilterRule]
    }

    func plan() -> Plan {
        var conditions: [String] = []
        var bindings: [CQLValue] = []
        var clientRules: [FilterRule] = []
        for rule in rules where rule.isActive {
            // Only equality is safe server-side: range filters on partition keys need token().
            guard let name = rule.column, let column = columns.first(where: { $0.name == name }),
                  rule.filterOperator == .equals,
                  let value = CQLValue(rule.value, cqlType: column.dataType) else {
                clientRules.append(rule)
                continue
            }
            conditions.append("\(Self.quote(name)) = ?")
            bindings.append(value)
        }
        let selectList = columns.isEmpty ? "*" : columns.map { column in
            "\(Self.isScalar(column.dataType) ? "CAST(\(Self.quote(column.name)) AS text)" : "toJson(\(Self.quote(column.name)))") AS \(Self.quote(column.name))"
        }.joined(separator: ", ")
        var cql = "SELECT \(selectList) FROM \(Self.quote(object.schema)).\(Self.quote(object.name))"
        if !conditions.isEmpty { cql += " WHERE " + conditions.joined(separator: " AND ") }
        cql += " LIMIT \(clientRules.isEmpty ? max(limit, 0) : max(limit, clientSideScanLimit))"
        if !conditions.isEmpty { cql += " ALLOW FILTERING" }
        return Plan(cql: cql, bindings: bindings, clientRules: clientRules)
    }

    static func quote(_ identifier: String) -> String {
        identifier.quotedIdentifier
    }

    /// Types `CAST(… AS text)` accepts; collections, UDTs and tuples go through `toJson`.
    static func isScalar(_ cqlType: String) -> Bool {
        !["list<", "set<", "map<", "frozen<", "tuple<", "vector<"].contains { cqlType.hasPrefix($0) } && !cqlType.isEmpty
    }
}

/// A CQL bind value parsed from user text for a column type.
nonisolated enum CQLValue: Hashable, Sendable {
    case text(String)
    case int32(Int32)
    case int64(Int64)
    case double(Double)
    case bool(Bool)

    init?(_ raw: String, cqlType: String) {
        switch cqlType {
        case "text", "varchar", "ascii": self = .text(raw)
        case "int": guard let value = Int32(raw) else { return nil }; self = .int32(value)
        case "bigint", "counter": guard let value = Int64(raw) else { return nil }; self = .int64(value)
        case "double": guard let value = Double(raw) else { return nil }; self = .double(value)
        case "boolean": guard let value = Bool(raw.lowercased()) else { return nil }; self = .bool(value)
        default: return nil
        }
    }
}
