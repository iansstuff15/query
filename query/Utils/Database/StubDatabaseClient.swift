import Foundation

/// Deterministic in-memory client for previews and UI tests (`-UITesting`, `MOCK_DB`).
nonisolated struct StubDatabaseClient: SQLConsoleRunning, RowUpdating, UserManaging {
    let scenario: StubScenario
    let delay: Duration

    init(scenario: StubScenario = .sample, delay: Duration = .zero) {
        self.scenario = scenario
        self.delay = delay
    }

    func listObjects() async throws -> [DatabaseObject] {
        try await simulateLatency()
        switch scenario {
        case .sample: return SampleCatalog.objects
        case .empty: return []
        case .failing: throw DatabaseError.connectionFailed
        }
    }

    func columns(of object: DatabaseObject) async throws -> [ColumnInfo] {
        try await simulateLatency()
        guard scenario != .failing else { throw DatabaseError.connectionFailed }
        return SampleCatalog.columns(for: object)
    }

    func rows(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) async throws -> QueryResult {
        try await simulateLatency()
        guard scenario != .failing else { throw DatabaseError.queryFailed }
        let evaluator = RowFilterEvaluator(columns: columns, rules: rules)
        let values = SampleCatalog.rows(for: object).filter(evaluator.matches).prefix(max(limit, 0))
        return QueryResult(columns: columns, values: Array(values))
    }

    func queryPreview(of object: DatabaseObject, columns: [ColumnInfo], rules: [FilterRule], limit: Int) -> String? {
        SQLPreview.text(RowFilterQuery(object: object, columns: columns, rules: rules, limit: limit).statement())
    }

    var canUpdateRows: Bool { true }

    func primaryKey(of object: DatabaseObject) async throws -> [String] {
        SampleCatalog.columns(for: object).first.map { [$0.name] } ?? []
    }

    // MARK: - Users (sample data; changes aren't kept)

    var userManagement: UserManagementCapabilities? { .postgres }

    func users() async throws -> [DatabaseUser] {
        try await simulateLatency()
        guard scenario != .failing else { throw DatabaseError.statementFailed("permission denied to list roles") }
        return [
            DatabaseUser(name: "postgres", host: nil, options: Set(UserOption.allCases)),
            DatabaseUser(name: "query_reader", host: nil, options: [.login]),
            DatabaseUser(name: "query_writer", host: nil, options: [.login]),
        ]
    }

    func createUser(_ draft: UserDraft) async throws { try await simulateLatency() }
    func updateUser(_ user: DatabaseUser, to draft: UserDraft) async throws { try await simulateLatency() }
    func dropUser(_ user: DatabaseUser) async throws { try await simulateLatency() }

    func grants(of user: DatabaseUser) async throws -> [GrantTarget: Set<TablePrivilege>] {
        try await simulateLatency()
        guard user.name != "postgres" else { return [:] }
        let tables = SampleCatalog.objects.filter { $0.schema == "public" }
        let privileges: Set<TablePrivilege> = user.name == "query_writer" ? Set(TablePrivilege.allCases) : [.select]
        return Dictionary(uniqueKeysWithValues: tables.map { (GrantTarget.table(schema: $0.schema, name: $0.name), privileges) })
    }

    func changeGrants(
        of user: DatabaseUser, granting added: [GrantTarget: Set<TablePrivilege>], revoking removed: [GrantTarget: Set<TablePrivilege>]
    ) async throws {
        try await simulateLatency()
    }

    /// Every column but the key.
    func editableColumns(of object: DatabaseObject) async throws -> Set<String>? {
        Set(SampleCatalog.columns(for: object).dropFirst().map(\.name))
    }

    /// Accepts every edit (nothing is stored).
    func update(_ change: RowChange) async throws {
        try await simulateLatency()
        guard scenario != .failing else { throw DatabaseError.statementFailed("permission denied for table \(change.object.name)") }
    }

    /// Any statement returns the sample customers.
    func runSQL(_ sql: String) async throws -> QueryResult {
        try await simulateLatency()
        guard scenario != .failing else { throw DatabaseError.queryFailed }
        return QueryResult(columns: SampleCatalog.customerColumns, values: SampleCatalog.customerRows)
    }

    private func simulateLatency() async throws {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
    }
}
