import SwiftData
import SwiftUI

/// First screen: every supported engine, and recent connections in a collapsible right-hand
/// column (checked in the background, one click to connect).
struct WelcomeView: View {
    @State private var model: WelcomeViewModel
    @State private var transfer: ConnectionTransferViewModel
    @State private var isExportShown = false
    @State private var isImporting = false
    @SceneStorage("welcome.recentShown") private var isRecentShown = true
    @Query(SavedConnectionQueries.recent) private var recent: [SavedConnection]
    @FocusState private var isSearchFocused: Bool
    private let onConnected: (ConnectionSession) -> Void

    init(
        factory: any DatabaseClientFactory, store: any ConnectionStore, clipboard: any ClipboardReading,
        flags: FeatureFlags = .current, onConnected: @escaping (ConnectionSession) -> Void
    ) {
        _model = State(initialValue: WelcomeViewModel(
            factory: factory, store: store, clipboard: clipboard, checksHealth: flags.connectionHealthChecks
        ))
        _transfer = State(initialValue: ConnectionTransferViewModel(store: store))
        self.onConnected = onConnected
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                engineGrid
                TransferStatusText(status: transfer.status)
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: Theme.Layout.welcomeMaxWidth)
            .frame(maxWidth: .infinity)
        }
        // The header floats above the grid; tiles scroll beneath it under the scroll edge effect.
        .safeAreaBar(edge: .top) { header }
        .inspector(isPresented: $isRecentShown) {
            recentColumn
                .inspectorColumnWidth(min: Theme.Layout.recentColumnMinWidth, ideal: Theme.Layout.recentColumnIdealWidth)
        }
        // Re-check when the set of saved connections changes (not when "last used" reorders it).
        .task(id: Set(recent.map(\.id))) { await model.checkHealth(of: recent) }
        .onChange(of: model.presentedForm == nil) { _, isClosed in
            // The sheet may have changed a connection's details.
            if isClosed { Task { await model.checkHealth(of: recent) } }
        }
        .sheet(item: $model.presentedForm) { form in
            ConnectionSheet(model: form, onConnected: onConnected)
        }
        .sheet(isPresented: $isExportShown) {
            ExportConnectionsSheet(model: transfer)
        }
        .sheet(isPresented: Binding(get: { transfer.pendingImport != nil }, set: { if !$0 { transfer.cancelImport() } })) {
            ImportPassphraseSheet(model: transfer)
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: ConnectionArchiveDocument.readableContentTypes) { result in
            guard case .success(let url) = result else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) { transfer.beginImport(data) }
        }
        .toolbar { toolbar }
        .focusedSceneValue(\.welcomeActions, WelcomeActions(exportConnections: showExport, importConnections: { isImporting = true }))
        .navigationTitle(L10n.welcomeTitle)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button { isImporting = true } label: {
                Label(L10n.importConnections, systemImage: "square.and.arrow.down")
            }
            .help(L10n.importHint)
            .accessibilityIdentifier(AccessibilityID.Transfer.importButton)

            Button(action: showExport) {
                Label(L10n.exportConnections, systemImage: "square.and.arrow.up")
            }
            .disabled(recent.isEmpty)
            .help(L10n.exportHint)
            .accessibilityIdentifier(AccessibilityID.Transfer.exportButton)
        }
        ToolbarSpacer(.fixed)
        ToolbarItem {
            Button { isRecentShown.toggle() } label: {
                Label(L10n.recentConnections, systemImage: "sidebar.right")
            }
            .help(L10n.recentToggleHelp)
            .accessibilityIdentifier(AccessibilityID.Welcome.recentToggle)
        }
    }

    private func showExport() {
        transfer.includeSecrets = false
        isExportShown = true
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(L10n.welcomeTitle).font(.largeTitle.bold())
            Text(L10n.welcomeSubtitle).foregroundStyle(.secondary)
            SearchField(
                text: $model.query, prompt: L10n.engineSearchPrompt, hint: L10n.engineSearchHint,
                identifier: AccessibilityID.Welcome.search, isFocused: $isSearchFocused
            )
            .frame(maxWidth: Theme.Layout.welcomeSearchWidth)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.l)
        .frame(maxWidth: Theme.Layout.welcomeMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    private var engineGrid: some View {
        Group {
            if model.engines.isEmpty {
                FallbackStateView(title: L10n.noMatches, systemImage: "magnifyingglass", message: L10n.noMatchesDetail, identifier: AccessibilityID.Welcome.empty)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: Theme.Layout.engineTileMinWidth), spacing: Theme.Spacing.m)], spacing: Theme.Spacing.m) {
                    ForEach(model.engines) { descriptor in
                        EngineTile(descriptor: descriptor) { model.choose(descriptor.engine) }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(AccessibilityID.Welcome.grid)
            }
        }
    }

    private var recentColumn: some View {
        List {
            Section {
                if recent.isEmpty {
                    Text(L10n.noRecentConnections)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(AccessibilityID.Welcome.recentEmpty)
                }
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, connection in
                    if let engine = connection.engine {
                        RecentConnectionRow(
                            name: connection.name, engine: engine, health: model.health(of: connection),
                            isConnecting: model.connectingID == connection.id, identifier: AccessibilityID.Welcome.recent(index),
                            onOpen: { open(connection) }, onEdit: { model.reopen(connection) }, onDelete: { model.delete(connection) }
                        )
                        .listRowInsets(EdgeInsets())
                    }
                }
            } header: {
                HStack {
                    Text(L10n.recentConnections)
                    Spacer()
                    Button { Task { await model.checkHealth(of: recent) } } label: {
                        Label(L10n.checkAgain, systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .disabled(recent.isEmpty)
                    .help(L10n.checkAgainHint)
                    .accessibilityHint(L10n.checkAgainHint)
                    .accessibilityIdentifier(AccessibilityID.Welcome.recentCheck)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier(AccessibilityID.Welcome.recentList)
    }

    private func open(_ connection: SavedConnection) {
        Task {
            if let session = await model.connect(connection) { onConnected(session) }
        }
    }
}

#Preview {
    WelcomeView(factory: StubDatabaseClientFactory(), store: PreviewConnectionStore(), clipboard: EmptyClipboard(), onConnected: { _ in })
        .modelContainer(for: SavedConnection.self, inMemory: true)
        .frame(width: 900, height: 700)
}
