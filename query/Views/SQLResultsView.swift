import SwiftUI

/// One SQL statement's latest result, in its own tab of the center panel, with how long it
/// took and how many rows came back along the bottom.
struct SQLResultsView: View {
    /// `nil` once the result was discarded (its tab is closing).
    let result: SQLQueryResult?

    var body: some View {
        content
            .safeAreaBar(edge: .bottom) { footer }
            .navigationTitle(Text(L10n.queryResults))
    }

    @ViewBuilder
    private var content: some View {
        switch result?.state {
        case nil:
            FallbackStateView(
                title: L10n.queryResultGoneTitle, systemImage: "terminal",
                message: L10n.queryResultGoneDetail, identifier: AccessibilityID.SQLConsole.placeholder
            )
        case .idle, .loading:
            SkeletonTable(identifier: AccessibilityID.SQLConsole.skeleton)
        case .loaded(let rows) where rows.columns.isEmpty || rows.isEmpty:
            FallbackStateView(
                title: L10n.sqlNoRowsTitle, systemImage: "checkmark.circle",
                message: L10n.sqlNoRowsDetail, identifier: AccessibilityID.SQLConsole.placeholder
            )
        case .loaded(let rows):
            ResultsTable(result: rows, identifier: AccessibilityID.SQLConsole.results)
        case .failed:
            FallbackStateView(
                title: L10n.sqlFailedTitle, systemImage: "exclamationmark.triangle",
                message: L10n.sqlFailedSeeConsole, identifier: AccessibilityID.SQLConsole.placeholder
            )
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let summary = result?.summary {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: summary.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(summary.succeeded ? Theme.Palette.statusSuccess : Theme.Palette.statusFailure)
                    .accessibilityLabel(summary.succeeded ? L10n.sqlSucceeded : L10n.sqlFailed)
                Text(summary.duration, format: .units(allowed: [.minutes, .seconds, .milliseconds], width: .abbreviated))
                if let rowCount = summary.rowCount {
                    Text(verbatim: "·")
                    Text(L10n.rowCount(rowCount))
                }
            }
            .font(Theme.Typography.footer)
            .foregroundStyle(.secondary)
            .barStyle()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AccessibilityID.SQLConsole.resultFooter)
        }
    }
}

#Preview {
    SQLResultsView(result: SQLQueryResult(
        id: "SELECT * FROM customers", sql: "SELECT * FROM customers",
        state: .loaded(QueryResult(columns: SampleCatalog.customerColumns, values: SampleCatalog.customerRows)),
        summary: SQLRunSummary(succeeded: true, duration: .milliseconds(14), rowCount: 12, errorMessage: nil)
    ))
    .frame(width: 800, height: 500)
}
