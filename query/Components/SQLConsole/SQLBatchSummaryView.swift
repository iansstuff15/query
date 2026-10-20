import SwiftUI

/// How the last run went: "Ran 2 of 3 statements · 34 ms", then each statement with its
/// status, duration, rows and (for a failure) the server's error. Clicking a statement shows its
/// result tab.
struct SQLBatchSummaryView: View {
    let batch: SQLBatchSummary
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: batch.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(batch.succeeded ? Theme.Palette.statusSuccess : Theme.Palette.statusFailure)
                    .accessibilityLabel(batch.succeeded ? L10n.sqlSucceeded : L10n.sqlFailed)
                Text(L10n.sqlBatchProgress(batch.entries.count, batch.requestedCount))
                Text(verbatim: "·").foregroundStyle(.secondary)
                Text(batch.duration, format: .units(allowed: [.minutes, .seconds, .milliseconds], width: .abbreviated))
                    .foregroundStyle(.secondary)
            }
            if batch.skippedCount > 0 {
                Text(L10n.sqlBatchStopped).foregroundStyle(.secondary)
            }
            ForEach(Array(batch.entries.enumerated()), id: \.element.id) { index, entry in
                Button { onSelect(entry.resultID) } label: {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(verbatim: entry.sql)
                            .font(Theme.Typography.sql)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        SQLRunSummaryView(summary: entry.summary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L10n.tabHint)
                .accessibilityHint(L10n.tabHint)
                .accessibilityIdentifier(AccessibilityID.SQLConsole.batchEntry(index))
                if index < batch.entries.count - 1 { Divider() }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.SQLConsole.batch)
    }
}

#Preview {
    SQLBatchSummaryView(
        batch: SQLBatchSummary(
            entries: [
                .init(id: UUID(), resultID: "SELECT 1", sql: "SELECT 1", summary: .init(succeeded: true, duration: .milliseconds(4), rowCount: 1, errorMessage: nil)),
                .init(id: UUID(), resultID: "DELETE FROM customers", sql: "DELETE FROM customers",
                      summary: .init(succeeded: false, duration: .milliseconds(2), rowCount: nil, errorMessage: "permission denied for table customers")),
            ],
            requestedCount: 3
        ),
        onSelect: { _ in }
    )
    .font(Theme.Typography.footer)
    .frame(width: 360)
    .padding()
}
