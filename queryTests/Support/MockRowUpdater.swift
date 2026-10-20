@testable import query

/// `RowUpdating` double that records saved changes and can fail like a read-only user.
actor MockRowUpdater: RowUpdating {
    nonisolated let canUpdateRows: Bool
    let key: [String]
    let failure: String?
    private(set) var changes: [RowChange] = []
    private(set) var keyLookups = 0

    init(canUpdateRows: Bool = true, key: [String] = ["id"], failure: String? = nil) {
        self.canUpdateRows = canUpdateRows
        self.key = key
        self.failure = failure
    }

    func primaryKey(of object: DatabaseObject) async throws -> [String] {
        keyLookups += 1
        return key
    }

    func update(_ change: RowChange) async throws {
        if let failure { throw DatabaseError.statementFailed(failure) }
        changes.append(change)
    }

    func listObjects() async throws -> [DatabaseObject] { [] }
    func columns(of object: DatabaseObject) async throws -> [ColumnInfo] { [] }
    func rows(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) async throws -> QueryResult {
        QueryResult(columns: columns, values: [])
    }
}
