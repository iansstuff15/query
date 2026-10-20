import Foundation
import Observation
import os

/// One database window: the object catalog, sidebar search and selection, the center panel's
/// tabs with back / forward history (like Xcode's editor), and Open Anything.
@MainActor
@Observable
final class WorkspaceViewModel {
    private(set) var objectsState: LoadState<[DatabaseObject]> = .idle
    /// Open tabs, left to right.
    private(set) var tabs: [WorkspaceTab] = []
    private(set) var activeTab: WorkspaceTab?
    var sidebarQuery = ""
    var matchingStrategy: MatchingStrategy = .fuzzy
    var isOpenAnythingShown = false
    /// Incremented to ask the sidebar to focus its search field.
    private(set) var sidebarSearchFocusRequest = 0
    /// The sidebar's selection; selecting an object opens (or switches to) its tab. Clearing the
    /// selection leaves the tabs alone.
    var selectedObjectID: DatabaseObject.ID? {
        didSet {
            guard oldValue != selectedObjectID, let selectedObjectID else { return }
            openTab(.object(selectedObjectID))
        }
    }

    private let client: any DatabaseClient
    private let rowLimit: Int
    /// One browser per open object tab, so switching tabs keeps rows and filters.
    private var browsers: [DatabaseObject.ID: TableBrowserViewModel] = [:]
    private var backStack: [WorkspaceTab] = []
    private var forwardStack: [WorkspaceTab] = []
    /// Called after a tab closes, so the SQL console can forget a closed query's result.
    var onTabClosed: ((WorkspaceTab) -> Void)?

    init(client: any DatabaseClient, rowLimit: Int = AppConfig.rowLimit) {
        self.client = client
        self.rowLimit = rowLimit
    }

    var objects: [DatabaseObject] { objectsState.value ?? [] }

    var matcher: TextMatcher { TextMatcher(strategy: matchingStrategy) }

    var sections: [SchemaSection] {
        ObjectSearch.sections(objects, query: sidebarQuery, matcher: matcher)
    }

    var selectedObject: DatabaseObject? {
        objects.first { $0.id == selectedObjectID }
    }

    /// The active tab's browser, when it shows an object.
    var browser: TableBrowserViewModel? {
        guard case .object(let id) = activeTab else { return nil }
        return browsers[id]
    }

    func object(for tab: WorkspaceTab) -> DatabaseObject? {
        guard case .object(let id) = tab else { return nil }
        return objects.first { $0.id == id }
    }

    /// Schemas in catalog order, for the jump bar.
    var schemas: [String] {
        var seen = Set<String>()
        return objects.map(\.schema).filter { seen.insert($0).inserted }
    }

    func objects(inSchema schema: String) -> [DatabaseObject] {
        objects.filter { $0.schema == schema }
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    /// Loads the catalog, then restores `restoringSelection` (from `@SceneStorage`) if present.
    func load(restoringSelection: DatabaseObject.ID? = nil) async {
        objectsState = .loading
        do {
            let loaded = try await client.listObjects()
            objectsState = .loaded(loaded)
            closeTabs { id in !loaded.contains { $0.id == id } }
            if let restoringSelection, selectedObjectID == nil, loaded.contains(where: { $0.id == restoringSelection }) {
                selectedObjectID = restoringSelection
            } else if let selectedObjectID, !loaded.contains(where: { $0.id == selectedObjectID }) {
                self.selectedObjectID = nil
            }
        } catch {
            AppLog.database.error("Loading objects failed: \(String(describing: error), privacy: .private)")
            objectsState = .failed(error)
            closeTabs { _ in true }
            selectedObjectID = nil
        }
    }

    func refresh() async {
        await load(restoringSelection: selectedObjectID)
        await browser?.reload()
    }

    func open(_ object: DatabaseObject, showingFilters: Bool = false) {
        openTab(.object(object.id))
        isOpenAnythingShown = false
        if showingFilters, let browser, !browser.isFilterBarShown {
            browser.toggleFilterBar()
        }
    }

    func showOpenAnything() {
        isOpenAnythingShown = true
    }

    func focusSidebarSearch() {
        sidebarSearchFocusRequest += 1
    }

    // MARK: - Tabs

    /// Opens `tab` (after the active one) if it isn't open yet, and switches to it.
    func openTab(_ tab: WorkspaceTab) {
        if !tabs.contains(tab) {
            let index = activeTab.flatMap { tabs.firstIndex(of: $0) }.map { $0 + 1 } ?? tabs.endIndex
            tabs.insert(tab, at: index)
        }
        activate(tab)
    }

    /// Switches to a SQL statement's result tab, opening it if needed.
    func showQuery(_ key: String) {
        openTab(.query(key))
    }

    func activate(_ tab: WorkspaceTab) {
        activate(tab, recordingHistory: true)
    }

    func closeTab(_ tab: WorkspaceTab) {
        guard let index = tabs.firstIndex(of: tab) else { return }
        tabs.remove(at: index)
        if case .object(let id) = tab { browsers[id] = nil }
        backStack.removeAll { $0 == tab }
        forwardStack.removeAll { $0 == tab }
        onTabClosed?(tab)
        guard activeTab == tab else { return }
        if tabs.isEmpty {
            activeTab = nil
            selectedObjectID = nil
        } else {
            activate(tabs[min(index, tabs.count - 1)], recordingHistory: false)
        }
    }

    func closeOtherTabs(than tab: WorkspaceTab) {
        for other in tabs where other != tab { closeTab(other) }
        activate(tab, recordingHistory: false)
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        if let activeTab { forwardStack.append(activeTab) }
        activate(previous, recordingHistory: false)
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        if let activeTab { backStack.append(activeTab) }
        activate(next, recordingHistory: false)
    }

    private func activate(_ tab: WorkspaceTab, recordingHistory: Bool) {
        guard tab != activeTab else { return }
        if !tabs.contains(tab) { tabs.append(tab) }
        if recordingHistory, let activeTab {
            backStack.append(activeTab)
            forwardStack.removeAll()
        }
        activeTab = tab
        // History never points at the tab you're already on (e.g. after closing a tab).
        while backStack.last == tab { backStack.removeLast() }
        while forwardStack.last == tab { forwardStack.removeLast() }
        switch tab {
        case .object(let id):
            if browsers[id] == nil, let object = objects.first(where: { $0.id == id }) {
                browsers[id] = TableBrowserViewModel(object: object, client: client, rowLimit: rowLimit)
            }
            if selectedObjectID != id { selectedObjectID = id }
        case .query:
            // Nothing in the sidebar is shown, so clicking the last table switches back to it.
            selectedObjectID = nil
        }
    }

    private func closeTabs(where isGone: (DatabaseObject.ID) -> Bool) {
        for tab in tabs {
            if case .object(let id) = tab, isGone(id) { closeTab(tab) }
        }
    }
}
