@testable import query

/// `SQLConsoleRunning` double that records what it was asked to run.
actor MockSQLClient: SQLConsoleRunning {
    var result: Result<QueryResult, MockError>
    let gate: Gate?
    /// Statements that fail with a server message, whatever `result` is.
    let failing: Set<String>
    private(set) var ranSQL: [String] = []

    init(
        result: Result<QueryResult, MockError> = .success(QueryResult(columnNames: ["n"], values: [["1"]])), gate: Gate? = nil,
        failing: Set<String> = []
    ) {
        self.result = result
        self.gate = gate
        self.failing = failing
    }

    func runSQL(_ sql: String) async throws -> QueryResult {
        ranSQL.append(sql)
        await gate?.pass()
        if failing.contains(sql) { throw DatabaseError.statementFailed("failed: \(sql)") }
        return try result.get()
    }

    func listObjects() async throws -> [DatabaseObject] { [] }
    func columns(of object: DatabaseObject) async throws -> [ColumnInfo] { [] }
    func rows(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) async throws -> QueryResult {
        QueryResult(columns: columns, values: [])
    }
}
