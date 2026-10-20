import SwiftUI

/// A database window: sidebar + center panel with an Xcode-style header (tabs for open tables and
/// the SQL results, then a jump bar) and a loading bar under it, a collapsible SQL console on the
/// right, toolbar, Open Anything sheet, and menu actions.
struct WorkspaceView: View {
    @State private var model: WorkspaceViewModel
    @State private var console: SQLConsoleViewModel
    @SceneStorage("workspace.selection") private var storedSelection: String?
    @SceneStorage("workspace.sqlConsoleShown") private var isConsoleShown = true
    @SceneStorage("workspace.sql") private var storedSQL = ""
    @SceneStorage("workspace.sqlConsoleTab") private var consoleTab: SQLConsoleTab = .editor
    @State private var isImportingSQL = false
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.matchingStrategy) private var matchingStrategy: MatchingStrategy = .fuzzy

    private let session: ConnectionSession
    private let onDisconnect: () -> Void

    /// Info.plist toggles for the SQL console, its history and row editing.
    private let flags: FeatureFlags

    init(session: ConnectionSession, history: any SQLHistoryStore, flags: FeatureFlags = .current, onDisconnect: @escaping () -> Void) {
        self.flags = flags
        self.session = session
        self.onDisconnect = onDisconnect
        _model = State(initialValue: WorkspaceViewModel(client: session.client))
        _console = State(initialValue: SQLConsoleViewModel(
            client: session.client, connectionID: session.id, history: history, recordsHistory: flags.sqlHistory
        ))
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
                .navigationSplitViewColumnWidth(min: Theme.Layout.sidebarMinWidth, ideal: Theme.Layout.sidebarIdealWidth)
        } detail: {
            // The header is a solid bar above the panel (not a `safeAreaBar`, whose scroll edge
            // effect drew over the rows), with the loading bar right under it.
            VStack(spacing: 0) {
                EditorHeaderView(model: model, session: session)
                    .zIndex(1)
                centerPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .overlay(alignment: .top) {
                        LoadingBar(isActive: isLoading, identifier: AccessibilityID.Detail.loadingBar)
                    }
            }
        }
        .inspector(isPresented: consoleShown) {
            SQLConsoleView(
                model: console, objects: model.objects, tab: currentPanelTab, tabs: panelTabs, rowEditor: model.browser?.editor,
                onOpenFile: openSQLFile
            )
                .inspectorColumnWidth(
                    min: Theme.Layout.sqlConsoleMinWidth, ideal: Theme.Layout.sqlConsoleIdealWidth, max: Theme.Layout.sqlConsoleMaxWidth
                )
        }
        .toolbar { toolbar }
        .fileImporter(isPresented: $isImportingSQL, allowedContentTypes: SQLFileReader.contentTypes) { result in
            guard case .success(let url) = result else { return }
            console.importSQL(from: url)
            consoleTab = .editor
            isConsoleShown = true
        }
        // Selecting a row shows its fields in the right panel's Row tab.
        .onChange(of: model.browser?.selectedRowID) { _, rowID in
            guard rowID != nil, console.isSupported, flags.rowEditing else { return }
            consoleTab = .row
            isConsoleShown = true
        }
        .sheet(isPresented: $model.isOpenAnythingShown) {
            OpenAnythingView(objects: model.objects, matcher: model.matcher) { model.open($0) }
        }
        .focusedSceneValue(\.workspaceActions, actions)
        .navigationTitle(Text(verbatim: session.name))
        .navigationSubtitle(Text(verbatim: EngineCatalog.descriptor(for: session.engine).displayName))
        .task { await model.load(restoringSelection: storedSelection) }
        .onChange(of: model.selectedObjectID) { _, selection in
            if let selection { storedSelection = selection }
        }
        // As each statement starts, open its tab (reused for the same query) and show it.
        .onChange(of: console.focusRequest) { _, request in
            if let request { model.showQuery(request.resultID) }
        }
        .onChange(of: matchingStrategy, initial: true) { _, strategy in
            model.matchingStrategy = strategy
        }
        .onAppear {
            if console.text.isEmpty { console.text = storedSQL }
            model.onTabClosed = { [console] tab in
                if case .query(let key) = tab { console.discardResult(key) }
            }
        }
        .onChange(of: console.text) { _, text in storedSQL = text }
    }

    @ViewBuilder
    private var centerPanel: some View {
        if case .query(let key) = model.activeTab {
            SQLResultsView(result: console.result(for: key))
                .id(key)
        } else if let browser = model.browser {
            TableDetailView(model: browser)
                .id(browser.object.id)
        } else {
            FallbackStateView(
                title: L10n.selectObject, systemImage: "tablecells",
                message: L10n.selectObjectDetail, identifier: AccessibilityID.Detail.placeholder
            )
        }
    }

    /// Catalog, table rows or a SQL run in flight.
    private var isLoading: Bool {
        model.objectsState.isLoading || console.isRunning
            || model.browser?.resultState.isLoading == true
    }

    /// Engines without SQL never show the console.
    /// Engines without SQL, or with every panel feature off, never show the right panel.
    private var consoleShown: Binding<Bool> {
        Binding(get: { isConsoleShown && hasPanel }, set: { isConsoleShown = $0 })
    }

    /// The right panel's tabs: Editor and History with the SQL console (History only when
    /// recorded), Row with row editing.
    private var panelTabs: [SQLConsoleTab] {
        var tabs: [SQLConsoleTab] = []
        if flags.sqlConsole { tabs.append(.editor) }
        if flags.sqlConsole && flags.sqlHistory { tabs.append(.history) }
        if flags.rowEditing { tabs.append(.row) }
        return tabs
    }

    private var hasPanel: Bool { console.isSupported && !panelTabs.isEmpty }

    /// The stored tab, or the first available one if it's been turned off.
    private var currentPanelTab: Binding<SQLConsoleTab> {
        Binding(
            get: { panelTabs.contains(consoleTab) ? consoleTab : (panelTabs.first ?? .editor) },
            set: { consoleTab = $0 }
        )
    }

    private var canUseEditor: Bool { console.isSupported && flags.sqlConsole }

    private var canManageUsers: Bool {
        flags.userManagement && (session.client as? any UserManaging)?.userManagement != nil
    }

    private func manageUsers() {
        guard canManageUsers else { return }
        openWindow(id: SceneID.users, value: session.id)
    }

    private func toggleConsole() {
        isConsoleShown.toggle()
    }

    private func openSQLFile() {
        guard canUseEditor else { return }
        isImportingSQL = true
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: onDisconnect) {
                Label(L10n.disconnect, systemImage: "eject")
            }
            .help(L10n.disconnectHelp)
            .accessibilityIdentifier(AccessibilityID.Toolbar.disconnect)
        }
        ToolbarItemGroup {
            Button(action: model.showOpenAnything) {
                Label(L10n.openAnything, systemImage: "magnifyingglass")
            }
            .help(L10n.openAnythingHelp)
            .accessibilityIdentifier(AccessibilityID.Toolbar.openAnything)
        }
        // Separate glass groups: navigation (Open Anything) vs. actions on the current table.
        ToolbarSpacer(.fixed)
        ToolbarItemGroup {
            Button { model.browser?.toggleFilterBar() } label: {
                Label(L10n.filters, systemImage: "line.3.horizontal.decrease.circle")
            }
            .disabled(model.browser == nil)
            .help(L10n.filtersHelp)
            .accessibilityIdentifier(AccessibilityID.Toolbar.filters)

            Button { Task { await model.refresh() } } label: {
                Label(L10n.refresh, systemImage: "arrow.clockwise")
            }
            .help(L10n.refreshHelp)
            .accessibilityIdentifier(AccessibilityID.Toolbar.refresh)
        }
        ToolbarSpacer(.fixed)
        ToolbarItem {
            Button(action: manageUsers) {
                Label(L10n.manageUsers, systemImage: "person.2")
            }
            .disabled(!canManageUsers)
            .help(L10n.manageUsersHelp)
            .accessibilityIdentifier(AccessibilityID.Toolbar.manageUsers)
        }
        ToolbarItem {
            Button(action: toggleConsole) {
                Label(L10n.sqlConsole, systemImage: "sidebar.right")
            }
            .disabled(!hasPanel)
            .help(L10n.sqlConsoleHelp)
            .accessibilityIdentifier(AccessibilityID.Toolbar.sqlConsole)
        }
    }

    private var actions: WorkspaceActions {
        WorkspaceActions(
            openAnything: model.showOpenAnything,
            refresh: { Task { await model.refresh() } },
            toggleFilters: { model.browser?.toggleFilterBar() },
            focusSidebarSearch: model.focusSidebarSearch,
            disconnect: onDisconnect,
            toggleSQLConsole: toggleConsole,
            openSQLFile: openSQLFile,
            manageUsers: manageUsers,
            canManageUsers: canManageUsers,
            goBack: model.goBack,
            goForward: model.goForward,
            closeTab: { if let tab = model.activeTab { model.closeTab(tab) } },
            canFilter: model.browser != nil,
            canUseSQLConsole: canUseEditor,
            canGoBack: model.canGoBack,
            canGoForward: model.canGoForward,
            hasActiveTab: model.activeTab != nil
        )
    }
}

#Preview {
    WorkspaceView(
        session: ConnectionSession(id: UUID(), name: "Preview", engine: .postgreSQL, client: StubDatabaseClient()),
        history: InMemorySQLHistoryStore(), onDisconnect: {}
    )
}
