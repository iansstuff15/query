import Foundation
import Testing
@testable import query

@MainActor
@Suite("WorkspaceViewModel")
struct WorkspaceViewModelTests {
    @Test func loadSuccessPopulatesSections() async {
        let model = WorkspaceViewModel(client: MockDatabaseClient())
        await model.load()
        #expect(model.objects == SampleCatalog.objects)
        #expect(model.sections.map(\.schema) == ["analytics", "public", "sales"])
    }

    @Test func showsLoadingWhileFetching() async {
        let gate = Gate()
        let model = WorkspaceViewModel(client: MockDatabaseClient(gate: gate))
        let task = Task { await model.load() }
        await gate.waitUntilEntered()
        #expect(model.objectsState.isLoading)
        await gate.open()
        await task.value
        #expect(model.objectsState.value?.count == SampleCatalog.objects.count)
    }

    @Test func emptyCatalogLoadsEmpty() async {
        let model = WorkspaceViewModel(client: MockDatabaseClient(objects: .success([])))
        await model.load()
        #expect(model.objectsState.value == [])
        #expect(model.sections.isEmpty)
    }

    @Test func failureIsSilentAndClearsSelection() async {
        let client = MockDatabaseClient()
        let model = WorkspaceViewModel(client: client)
        await model.load()
        model.selectedObjectID = Fixtures.customers.id
        await client.setObjects(.failure(MockError()))
        await model.load()
        guard case .failed = model.objectsState else {
            Issue.record("Expected failed state")
            return
        }
        #expect(model.objects.isEmpty)
        #expect(model.selectedObjectID == nil)
        #expect(model.browser == nil)
    }

    @Test func restoresSceneSelection() async {
        let model = WorkspaceViewModel(client: MockDatabaseClient())
        await model.load(restoringSelection: Fixtures.orders.id)
        #expect(model.selectedObjectID == Fixtures.orders.id)
        #expect(model.browser?.object == Fixtures.orders)
    }

    @Test func ignoresUnknownRestoredSelection() async {
        let model = WorkspaceViewModel(client: MockDatabaseClient())
        await model.load(restoringSelection: "public.gone")
        #expect(model.selectedObjectID == nil)
    }

    @Test func sidebarQueryFiltersWithStrategy() async {
        let model = WorkspaceViewModel(client: MockDatabaseClient())
        await model.load()
        model.sidebarQuery = "ord"
        #expect(model.sections.flatMap(\.objects).map(\.name).contains("recent_orders"))
        model.matchingStrategy = .prefix
        #expect(model.sections.flatMap(\.objects).map(\.name) == ["order_items", "orders", "orderLineSummary"])
    }

    @Test func openingFromPaletteSelectsAndShowsFilters() async {
        let model = WorkspaceViewModel(client: MockDatabaseClient())
        await model.load()
        model.showOpenAnything()
        model.open(Fixtures.customers, showingFilters: true)
        #expect(!model.isOpenAnythingShown)
        #expect(model.selectedObject == Fixtures.customers)
        #expect(model.browser?.isFilterBarShown == true)
        #expect(model.browser?.rules.count == 1)
    }

    @Test func clearingTheSidebarSelectionKeepsTheTabOpen() async {
        let model = WorkspaceViewModel(client: MockDatabaseClient())
        await model.load()
        model.selectedObjectID = Fixtures.customers.id
        let first = model.browser
        model.selectedObjectID = Fixtures.customers.id
        #expect(model.browser === first)
        model.selectedObjectID = nil
        #expect(model.browser === first)
        #expect(model.tabs == [.object(Fixtures.customers.id)])
    }

    // MARK: - Tabs

    @Test func eachSelectionOpensATabAndKeepsItsBrowser() async {
        let model = WorkspaceViewModel(client: MockDatabaseClient())
        await model.load()
        model.selectedObjectID = Fixtures.customers.id
        let customers = model.browser
        model.selectedObjectID = Fixtures.orders.id
        #expect(model.tabs == [.object(Fixtures.customers.id), .object(Fixtures.orders.id)])
        #expect(model.activeTab == .object(Fixtures.orders.id))
        model.activate(.object(Fixtures.customers.id))
        #expect(model.browser === customers)
        #expect(model.selectedObjectID == Fixtures.customers.id)
    }

    @Test func newTabsOpenNextToTheActiveOne() async {
        let model = WorkspaceViewModel(client: MockDatabaseClient())
        await model.load()
        model.open(Fixtures.customers)
        model.open(Fixtures.orders)
        model.activate(.object(Fixtures.customers.id))
        model.showQuery("SELECT 1")
        #expect(model.tabs == [.object(Fixtures.customers.id), .query("SELECT 1"), .object(Fixtures.orders.id)])
    }

    @Test func backAndForwardRetraceVisitedTabs() async {
        let model = WorkspaceViewModel(client: MockDatabaseClient())
        await model.load()
        #expect(!model.canGoBack)
        model.open(Fixtures.customers)
        model.open(Fixtures.orders)
        model.showQuery("SELECT 1")
        model.goBack()
        #expect(model.activeTab == .object(Fixtures.orders.id))
        model.goBack()
        #expect(model.activeTab == .object(Fixtures.customers.id))
        #expect(!model.canGoBack)
        model.goForward()
        #expect(model.activeTab == .object(Fixtures.orders.id))
        // Going somewhere new drops the forward history.
        model.activate(.object(Fixtures.customers.id))
        #expect(!model.canGoForward)
    }

    @Test func aQueryTabClearsTheSidebarSelection() async {
        let model = WorkspaceViewModel(client: MockDatabaseClient())
        await model.load()
        model.open(Fixtures.customers)
        model.showQuery("SELECT 1")
        #expect(model.activeTab == .query("SELECT 1"))
        #expect(model.selectedObjectID == nil)
        #expect(model.browser == nil)
        // Clicking the same table in the sidebar switches back to it.
        model.selectedObjectID = Fixtures.customers.id
        #expect(model.activeTab == .object(Fixtures.customers.id))
    }

    @Test func closingTheActiveTabActivatesItsNeighbor() async {
        let model = WorkspaceViewModel(client: MockDatabaseClient())
        await model.load()
        model.open(Fixtures.customers)
        model.open(Fixtures.orders)
        model.closeTab(.object(Fixtures.orders.id))
        #expect(model.activeTab == .object(Fixtures.customers.id))
        #expect(!model.canGoBack)
        model.closeTab(.object(Fixtures.customers.id))
        #expect(model.tabs.isEmpty)
        #expect(model.activeTab == nil)
        #expect(model.selectedObjectID == nil)
    }

    @Test func closeOtherTabsKeepsOne() async {
        let model = WorkspaceViewModel(client: MockDatabaseClient())
        await model.load()
        model.open(Fixtures.customers)
        model.open(Fixtures.orders)
        model.showQuery("SELECT 1")
        model.closeOtherTabs(than: .object(Fixtures.customers.id))
        #expect(model.tabs == [.object(Fixtures.customers.id)])
        #expect(model.activeTab == .object(Fixtures.customers.id))
    }

    @Test func reloadingClosesTabsForObjectsThatAreGone() async {
        let client = MockDatabaseClient()
        let model = WorkspaceViewModel(client: client)
        await model.load()
        model.open(Fixtures.customers)
        model.open(Fixtures.orders)
        await client.setObjects(.success([Fixtures.customers]))
        await model.load()
        #expect(model.tabs == [.object(Fixtures.customers.id)])
        #expect(model.activeTab == .object(Fixtures.customers.id))
    }

    @Test func eachQueryHasItsOwnTabAndClosingOneReportsIt() async {
        let model = WorkspaceViewModel(client: MockDatabaseClient())
        var closed: [WorkspaceTab] = []
        model.onTabClosed = { closed.append($0) }
        model.showQuery("SELECT 1")
        model.showQuery("SELECT 2")
        model.showQuery("SELECT 1")
        #expect(model.tabs == [.query("SELECT 1"), .query("SELECT 2")])
        #expect(model.activeTab == .query("SELECT 1"))
        model.closeTab(.query("SELECT 2"))
        #expect(closed == [.query("SELECT 2")])
    }

    @Test func jumpBarListsSchemasAndTheirObjects() async {
        let model = WorkspaceViewModel(client: MockDatabaseClient())
        await model.load()
        #expect(model.schemas == Array(NSOrderedSet(array: SampleCatalog.objects.map(\.schema))) as? [String])
        #expect(model.objects(inSchema: Fixtures.customers.schema).contains(Fixtures.customers))
        #expect(model.object(for: .object(Fixtures.orders.id)) == Fixtures.orders)
        #expect(model.object(for: .query("SELECT 1")) == nil)
    }

    @Test func refreshReloadsCatalogAndRows() async {
        let client = MockDatabaseClient()
        let model = WorkspaceViewModel(client: client)
        await model.load()
        model.selectedObjectID = Fixtures.customers.id
        await model.refresh()
        #expect(await client.listCallCount == 2)
        #expect(await client.rowsCallCount == 1)
        #expect(model.selectedObjectID == Fixtures.customers.id)
    }

    @Test func focusSidebarSearchBumpsRequest() {
        let model = WorkspaceViewModel(client: MockDatabaseClient())
        model.focusSidebarSearch()
        model.focusSidebarSearch()
        #expect(model.sidebarSearchFocusRequest == 2)
    }
}
