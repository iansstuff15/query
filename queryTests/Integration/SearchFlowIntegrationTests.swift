import Testing
@testable import query

/// Workspace + Open Anything + TableBrowser + StubDatabaseClient + RowFilterEvaluator together.
@MainActor
@Suite("Search flow", .tags(.integration))
struct SearchFlowIntegrationTests {
    @Test func openAnythingThenFilterRows() async throws {
        let workspace = WorkspaceViewModel(client: StubDatabaseClient(), rowLimit: 100)
        await workspace.load()

        let palette = OpenAnythingViewModel(objects: workspace.objects, matcher: workspace.matcher)
        palette.query = "cust"
        let picked = try #require(palette.highlightedObject)
        workspace.open(picked, showingFilters: true)

        let browser = try #require(workspace.browser)
        await browser.loadIfNeeded()
        #expect(browser.rowCount == SampleCatalog.customerRows.count)

        browser.rules = [FilterRule(column: "email", filterOperator: .endsWith, value: "example.com")]
        await browser.applyFilters()
        #expect(browser.rowCount == 4)
        #expect(browser.previewText?.contains(#"FROM "public"."customers" WHERE CAST("email" AS text) ILIKE $1 LIMIT 100"#) == true)
    }

    @Test func anyColumnAndNullFilters() async throws {
        let browser = TableBrowserViewModel(object: Fixtures.customers, client: StubDatabaseClient())
        await browser.loadIfNeeded()

        browser.rules = [FilterRule(column: nil, filterOperator: .equals, value: "GB")]
        await browser.applyFilters()
        #expect(browser.rowCount == 2)

        browser.rules = [FilterRule(column: "country", filterOperator: .isNull)]
        await browser.applyFilters()
        #expect(browser.rowCount == 1)

        await browser.clearFilters()
        #expect(browser.rowCount == SampleCatalog.customerRows.count)
    }

    @Test func failingBackendDegradesToEmptyStates() async {
        let workspace = WorkspaceViewModel(client: StubDatabaseClient(scenario: .failing))
        await workspace.load()
        #expect(workspace.objects.isEmpty)
        #expect(workspace.sections.isEmpty)

        let browser = TableBrowserViewModel(object: Fixtures.customers, client: StubDatabaseClient(scenario: .failing))
        await browser.loadIfNeeded()
        #expect(browser.rowCount == 0)
    }
}
