@testable import query

struct MockError: Error, Equatable {}

/// Configurable, recording `DatabaseClient` double.
actor MockDatabaseClient: DatabaseClient {
    var objectsResult: Result<[DatabaseObject], MockError>
    var columnsResult: Result<[ColumnInfo], MockError>
    var rowsResult: Result<[[String?]], MockError>
    let gate: Gate?

    private(set) var listCallCount = 0
    private(set) var columnsCallCount = 0
    private(set) var rowsCallCount = 0
    private(set) var lastRules: [FilterRule] = []
    private(set) var lastLimit: Int?

    init(
        objects: Result<[DatabaseObject], MockError> = .success(SampleCatalog.objects),
        columns: Result<[ColumnInfo], MockError> = .success(SampleCatalog.customerColumns),
        rows: Result<[[String?]], MockError> = .success(SampleCatalog.customerRows),
        gate: Gate? = nil
    ) {
        objectsResult = objects
        columnsResult = columns
        rowsResult = rows
        self.gate = gate
    }

    func setObjects(_ result: Result<[DatabaseObject], MockError>) {
        objectsResult = result
    }

    func setRows(_ result: Result<[[String?]], MockError>) {
        rowsResult = result
    }

    func listObjects() async throws -> [DatabaseObject] {
        listCallCount += 1
        await gate?.pass()
        return try objectsResult.get()
    }

    func columns(of object: DatabaseObject) async throws -> [ColumnInfo] {
        columnsCallCount += 1
        return try columnsResult.get()
    }

    func rows(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) async throws -> QueryResult {
        rowsCallCount += 1
        lastRules = rules
        lastLimit = limit
        await gate?.pass()
        return QueryResult(columns: columns, values: try rowsResult.get())
    }
}
