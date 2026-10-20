import SwiftUI

/// Result grid with one column per result column; `NULL` is shown dimmed. Used for SQL query
/// results; table tabs use `DataGrid`, whose rows can be selected and edited.
struct ResultsTable: View {
    let result: QueryResult
    var identifier = AccessibilityID.Detail.results

    var body: some View {
        Table(result.rows) {
            TableColumnForEach(result.columns) { column in
                TableColumn(column.name) { row in
                    if let value = row[column] {
                        Text(verbatim: value)
                            .font(Theme.Typography.cell)
                            .textSelection(.enabled)
                    } else {
                        Text(verbatim: "NULL")
                            .font(Theme.Typography.cell)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    ResultsTable(result: QueryResult(columns: SampleCatalog.customerColumns, values: SampleCatalog.customerRows))
        .frame(width: 800, height: 400)
}
