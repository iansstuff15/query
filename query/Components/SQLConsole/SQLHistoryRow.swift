import SwiftUI

/// A past run in the History tab: the SQL, how it went, and a Run button at the right end.
struct SQLHistoryRow: View {
    let item: SQLHistoryItem
    let isRunDisabled: Bool
    let identifier: String
    let onRun: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            Image(systemName: item.summary.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(item.summary.succeeded ? Theme.Palette.statusSuccess : Theme.Palette.statusFailure)
                .accessibilityLabel(item.summary.succeeded ? L10n.sqlSucceeded : L10n.sqlFailed)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(verbatim: item.sql)
                    .font(Theme.Typography.sql)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .help(Text(verbatim: item.sql))
                details
                    .font(Theme.Typography.footer)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onRun) {
                Label(L10n.runSQL, systemImage: "play.fill")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .disabled(isRunDisabled)
            .help(L10n.runHistoryHint)
            .accessibilityHint(L10n.runHistoryHint)
            .accessibilityIdentifier("\(identifier).run")
        }
        .paletteRow(isHighlighted: false, isHovered: isHovered)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(action: onRun) { Label(L10n.runSQL, systemImage: "play.fill") }
                .disabled(isRunDisabled)
            Button(action: onEdit) { Label(L10n.openInEditor, systemImage: "square.and.pencil") }
            Divider()
            Button(role: .destructive, action: onDelete) { Label(L10n.deleteHistoryItem, systemImage: "trash") }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private var details: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(item.ranAt, format: .relative(presentation: .named))
            Text(verbatim: "·")
            Text(item.summary.duration, format: .units(allowed: [.minutes, .seconds, .milliseconds], width: .abbreviated))
            if let rowCount = item.summary.rowCount {
                Text(verbatim: "·")
                Text(L10n.rowCount(rowCount))
            }
        }
    }
}

#Preview {
    VStack {
        SQLHistoryRow(
            item: SQLHistoryItem(
                id: UUID(), sql: "SELECT * FROM customers WHERE country = 'US' ORDER BY full_name;", ranAt: .now.addingTimeInterval(-90),
                summary: SQLRunSummary(succeeded: true, duration: .milliseconds(12), rowCount: 7, errorMessage: nil)
            ),
            isRunDisabled: false, identifier: "preview.0", onRun: {}, onEdit: {}, onDelete: {}
        )
        SQLHistoryRow(
            item: SQLHistoryItem(
                id: UUID(), sql: "DELETE FROM customers WHERE id = 1;", ranAt: .now.addingTimeInterval(-600),
                summary: SQLRunSummary(succeeded: false, duration: .milliseconds(3), rowCount: nil, errorMessage: "permission denied")
            ),
            isRunDisabled: false, identifier: "preview.1", onRun: {}, onEdit: {}, onDelete: {}
        )
    }
    .frame(width: 380)
    .padding()
}
