import Testing
@testable import query

@MainActor
@Suite("TableBrowserViewModel")
struct TableBrowserViewModelTests {
    private func makeModel(_ client: MockDatabaseClient = MockDatabaseClient()) -> TableBrowserViewModel {
        TableBrowserViewModel(object: Fixtures.customers, client: client, rowLimit: 25)
    }

    @Test func loadsColumnsThenRowsOnce() async {
        let client = MockDatabaseClient()
        let model = makeModel(client)
        await model.loadIfNeeded()
        await model.loadIfNeeded()
        #expect(model.columns == SampleCatalog.customerColumns)
        #expect(model.rowCount == SampleCatalog.customerRows.count)
        #expect(await client.columnsCallCount == 1)
        #expect(await client.rowsCallCount == 1)
        #expect(await client.lastLimit == 25)
    }

    @Test func showsLoadingWhileFetching() async {
        let gate = Gate()
        let model = makeModel(MockDatabaseClient(gate: gate))
        let task = Task { await model.reload() }
        await gate.waitUntilEntered()
        #expect(model.resultState.isLoading)
        await gate.open()
        await task.value
        #expect(model.resultState.value != nil)
    }

    @Test func emptyResultLoadsEmpty() async {
        let model = makeModel(MockDatabaseClient(rows: .success([])))
        await model.reload()
        #expect(model.resultState.value?.isEmpty == true)
        #expect(model.rowCount == 0)
    }

    @Test func failureIsSilent() async {
        let model = makeModel(MockDatabaseClient(rows: .failure(MockError())))
        await model.reload()
        guard case .failed = model.resultState else {
            Issue.record("Expected failed state")
            return
        }
        #expect(model.rowCount == 0)
    }

    @Test func columnFailureIsSilent() async {
        let client = MockDatabaseClient(columns: .failure(MockError()))
        let model = makeModel(client)
        await model.reload()
        guard case .failed = model.resultState else {
            Issue.record("Expected failed state")
            return
        }
        #expect(await client.rowsCallCount == 0)
    }

    @Test func onlyActiveRulesAreSentOnApply() async {
        let client = MockDatabaseClient()
        let model = makeModel(client)
        await model.loadIfNeeded()
        let active = FilterRule(column: "email", filterOperator: .contains, value: "example")
        model.rules = [active, FilterRule(value: ""), FilterRule(value: "x", isEnabled: false)]
        #expect(model.appliedRules.isEmpty)
        await model.applyFilters()
        #expect(model.appliedRules == [active])
        #expect(await client.lastRules == [active])
    }

    @Test func previewReflectsUnappliedEdits() async throws {
        let model = makeModel()
        await model.loadIfNeeded()
        model.rules = [FilterRule(column: "email", filterOperator: .contains, value: "ada")]
        #expect(model.previewText == nil) // the mock has no native preview
        let stub = TableBrowserViewModel(object: Fixtures.customers, client: StubDatabaseClient())
        await stub.loadIfNeeded()
        stub.rules = [FilterRule(column: "email", filterOperator: .contains, value: "ada")]
        let preview = try #require(stub.previewText)
        #expect(preview.contains(#"WHERE CAST("email" AS text) ILIKE $1 LIMIT 300"#))
        #expect(preview.hasSuffix("— 1 = '%ada%'"))
    }

    @Test func clearReloadsOnlyWhenFiltersWereApplied() async {
        let client = MockDatabaseClient()
        let model = makeModel(client)
        await model.loadIfNeeded()
        model.addRule()
        await model.clearFilters()
        #expect(await client.rowsCallCount == 1)
        model.rules = [FilterRule(value: "a")]
        await model.applyFilters()
        await model.clearFilters()
        #expect(await client.rowsCallCount == 3)
        #expect(model.rules.isEmpty)
        #expect(model.appliedRules.isEmpty)
    }

    @Test func toggleFilterBarSeedsOneRule() {
        let model = makeModel()
        model.toggleFilterBar()
        #expect(model.isFilterBarShown)
        #expect(model.rules.count == 1)
        model.toggleFilterBar()
        #expect(!model.isFilterBarShown)
        #expect(model.rules.count == 1)
    }

    @Test func duplicateAndRemoveRules() throws {
        let model = makeModel()
        let original = FilterRule(column: "id", filterOperator: .greaterThan, value: "3")
        model.rules = [original, FilterRule(value: "z")]
        model.duplicateRule(original.id)
        #expect(model.rules.count == 3)
        let copy = model.rules[1]
        #expect(copy.id != original.id)
        #expect(copy.column == "id" && copy.filterOperator == .greaterThan && copy.value == "3")
        model.removeRule(original.id)
        #expect(model.rules.count == 2)
        model.duplicateRule(original.id)
        #expect(model.rules.count == 2)
    }

    // MARK: - Row selection

    @Test func selectingARowOpensItsEditorAndReloadsKeepIt() async throws {
        let model = TableBrowserViewModel(object: Fixtures.customers, client: MockDatabaseClient())
        await model.loadIfNeeded()
        #expect(model.editor == nil)
        model.selectedRowID = 1
        let editor = try #require(model.editor)
        #expect(editor.rowID == 1)
        #expect(editor.fields.map(\.original) == model.selectedRow?.values)
        await model.reload()
        #expect(model.editor === editor)
        model.selectedRowID = nil
        #expect(model.editor == nil)
    }

    @Test func aRowThatDisappearsOnReloadIsDeselected() async {
        let client = MockDatabaseClient()
        let model = TableBrowserViewModel(object: Fixtures.customers, client: client)
        await model.loadIfNeeded()
        model.selectedRowID = 5
        await client.setRows(.success([]))
        await model.reload()
        #expect(model.selectedRowID == nil)
        #expect(model.editor == nil)
    }
}
