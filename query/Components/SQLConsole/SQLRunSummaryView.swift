import SwiftUI

/// The last SQL run: succeeded or failed (color and symbol), how long it took, rows returned,
/// and the server's error message when it failed.
struct SQLRunSummaryView: View {
    let summary: SQLRunSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            LabeledContent(L10n.sqlStatus) {
                Label(
                    summary.succeeded ? L10n.sqlSucceeded : L10n.sqlFailed,
                    systemImage: summary.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .foregroundStyle(summary.succeeded ? Theme.Palette.statusSuccess : Theme.Palette.statusFailure)
            }
            LabeledContent(L10n.sqlDuration) {
                Text(summary.duration, format: .units(allowed: [.minutes, .seconds, .milliseconds], width: .abbreviated))
            }
            if let rowCount = summary.rowCount {
                LabeledContent(L10n.sqlRowsReturned) {
                    Text(rowCount, format: .number)
                }
            }
            if !summary.succeeded {
                Group {
                    if let message = summary.errorMessage {
                        Text(verbatim: message)
                    } else {
                        Text(L10n.sqlFailedDetail)
                    }
                }
                .font(Theme.Typography.sql)
                .foregroundStyle(Theme.Palette.statusFailure)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(AccessibilityID.SQLConsole.error)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
        SQLRunSummaryView(summary: SQLRunSummary(succeeded: true, duration: .milliseconds(12), rowCount: 12, errorMessage: nil))
        SQLRunSummaryView(summary: SQLRunSummary(
            succeeded: false, duration: .milliseconds(3), rowCount: nil, errorMessage: "permission denied for table customers"
        ))
    }
    .frame(width: 320)
    .padding()
}
