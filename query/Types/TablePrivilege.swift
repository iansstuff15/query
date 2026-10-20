import Foundation

/// A privilege the permissions grid can grant or revoke on a table (or every table in a schema).
/// These names are the only privilege words ever written into SQL.
nonisolated enum TablePrivilege: String, CaseIterable, Identifiable, Hashable, Comparable, Sendable {
    case select = "SELECT"
    case insert = "INSERT"
    case update = "UPDATE"
    case delete = "DELETE"

    var id: String { rawValue }

    static func < (lhs: TablePrivilege, rhs: TablePrivilege) -> Bool {
        allCases.firstIndex(of: lhs) ?? 0 < allCases.firstIndex(of: rhs) ?? 0
    }

    /// Parses a catalog's privilege name ("SELECT", "Select", "select").
    init?(catalogName: String) {
        self.init(rawValue: catalogName.trimmingCharacters(in: .whitespaces).uppercased())
    }
}
