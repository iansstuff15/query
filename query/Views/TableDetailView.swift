import SwiftUI

/// Rows of the selected object, with the optional filter bar above them.
struct TableDetailView: View {
    @Bindable var model: TableBrowserViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.featureFlags) private var flags

    var body: some View {
        // Bars sit in the safe area so the grid scrolls beneath them with the system scroll
        // edge effect (Liquid Glass) instead of a custom opaque background.
        content
            .safeAreaBar(edge: .top) {
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
                }
            }
            .safeAreaBar(edge: .bottom) { footer }
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
            // Rows are selectable only when they can be edited in the Row tab.
            ResultsTable(result: result, selection: flags.rowEditing ? $model.selectedRowID : nil)
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
            .barStyle()
            .accessibilityIdentifier(AccessibilityID.Detail.rowCount)
    }
}

#Preview {
    TableDetailView(model: TableBrowserViewModel(object: SampleCatalog.objects[2], client: StubDatabaseClient()))
        .frame(width: 900, height: 500)
}
