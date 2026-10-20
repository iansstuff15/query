import SwiftUI

/// Schema-grouped objects with a local search field (no server round-trip).
struct SidebarView: View {
    @Bindable var model: WorkspaceViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SearchField(
                text: $model.sidebarQuery,
                prompt: L10n.sidebarSearchPrompt,
                hint: L10n.sidebarSearchHint,
                identifier: AccessibilityID.Sidebar.searchField,
                isFocused: $isSearchFocused
            )
            .padding(Theme.Spacing.s)
            content
        }
        .onChange(of: model.sidebarSearchFocusRequest) {
            isSearchFocused = true
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.objectsState {
        case .idle, .loading:
            SkeletonTable(rows: Theme.Layout.skeletonRows, columns: 1, identifier: AccessibilityID.Sidebar.skeleton)
        case .failed:
            FallbackStateView(
                title: L10n.noObjects, systemImage: "cylinder.split.1x2",
                message: L10n.noObjectsDetail, identifier: AccessibilityID.Sidebar.empty
            )
        case .loaded(let objects) where objects.isEmpty:
            FallbackStateView(
                title: L10n.noObjects, systemImage: "cylinder.split.1x2",
                message: L10n.noObjectsDetail, identifier: AccessibilityID.Sidebar.empty
            )
        case .loaded:
            let sections = model.sections
            if sections.isEmpty {
                FallbackStateView(
                    title: L10n.noMatches, systemImage: "magnifyingglass",
                    message: L10n.noMatchesDetail, identifier: AccessibilityID.Sidebar.empty
                )
            } else {
                List(selection: $model.selectedObjectID) {
                    ForEach(sections) { section in
                        Section(section.schema) {
                            ForEach(section.objects) { object in
                                DatabaseObjectRow(
                                    object: object,
                                    onOpen: { model.open(object) },
                                    onOpenWithFilters: { model.open(object, showingFilters: true) }
                                )
                                .tag(object.id)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .accessibilityIdentifier(AccessibilityID.Sidebar.list)
            }
        }
    }
}

#Preview {
    @Previewable @State var model = WorkspaceViewModel(client: StubDatabaseClient())
    NavigationSplitView {
        SidebarView(model: model)
    } detail: {
        EmptyView()
    }
    .task { await model.load() }
}
