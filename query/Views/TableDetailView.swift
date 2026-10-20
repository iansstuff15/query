import SwiftUI

/// Rows of the selected object, with the optional filter bar above them.
struct TableDetailView: View {
    @Bindable var model: TableBrowserViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.featureFlags) private var flags

    var body: some View {
        // Solid bars stacked around the grid rather than `safeAreaBar`s: the system's scroll
        // edge effect drew over the rows, made the bars see-through and took their clicks.
        VStack(spacing: 0) {
            if model.isFilterBarShown {
                FilterBar(
                    rules: $model.rules,
                    columns: model.columns,
                    preview: model.previewText,
                    onApply: { Task { await model.applyFilters() } },
                    onAdd: model.addRule,
                    onClear: { Task { await model.clearFilters() } },
                    onClone: model.duplicateRule,
                    onRemove: model.removeRule
                )
                .transition(Motion.filterBar)
                .zIndex(1)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            footer
        }
        .animation(Motion.animation(Motion.reveal, reduceMotion: reduceMotion), value: model.isFilterBarShown)
        .navigationTitle(Text(verbatim: model.object.name))
        .navigationSubtitle(Text(verbatim: model.object.schema))
        .task { await model.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.resultState {
        case .idle, .loading:
            SkeletonTable(identifier: AccessibilityID.Detail.skeleton)
        case .loaded(let result) where !result.isEmpty:
            // Rows are selectable (and get the selection-friendly grid) only when they can be
            // edited in the Row tab.
            if flags.rowEditing {
                DataGrid(result: result, selection: $model.selectedRowID)
            } else {
                ResultsTable(result: result)
            }
        case .loaded, .failed:
            FallbackStateView(
                title: L10n.noRows, systemImage: "line.3.horizontal.decrease.circle",
                message: L10n.noRowsDetail, identifier: AccessibilityID.Detail.empty
            )
        }
    }

    private var footer: some View {
        Text(L10n.rowCount(model.rowCount))
            .font(Theme.Typography.footer)
            .foregroundStyle(.secondary)
            .barStyle(divider: .top)
            .accessibilityIdentifier(AccessibilityID.Detail.rowCount)
    }
}

#Preview {
    TableDetailView(model: TableBrowserViewModel(object: SampleCatalog.objects[2], client: StubDatabaseClient()))
        .frame(width: 900, height: 500)
}
