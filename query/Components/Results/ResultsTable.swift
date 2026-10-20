import SwiftUI

/// Result grid with one column per result column; `NULL` is shown dimmed. With a selection
/// binding, each row is selectable.
struct ResultsTable: View {
    let result: QueryResult
    var identifier = AccessibilityID.Detail.results
    var selection: Binding<ResultRow.ID?>?

    var body: some View {
        if let selection {
            Table(result.rows, selection: selection) { columns }
                .accessibilityIdentifier(identifier)
        } else {
            Table(result.rows) { columns }
                .accessibilityIdentifier(identifier)
        }
    }

    @TableColumnBuilder<ResultRow, Never>
    private var columns: some TableColumnContent<ResultRow, Never> {
        TableColumnForEach(result.columns) { column in
            TableColumn(column.name) { row in
                if let value = row[column] {
                    // Selectable text would take the click that selects the row.
                    if selection == nil {
                        Text(verbatim: value).font(Theme.Typography.cell).textSelection(.enabled)
                    } else {
                        Text(verbatim: value).font(Theme.Typography.cell)
                    }
                } else {
                    Text(verbatim: "NULL")
                        .font(Theme.Typography.cell)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

#Preview {
    ResultsTable(result: QueryResult(columns: SampleCatalog.customerColumns, values: SampleCatalog.customerRows))
        .frame(width: 800, height: 400)
}
