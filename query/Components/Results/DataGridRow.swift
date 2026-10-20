import SwiftUI

/// One row of the data grid: a cell per column at the column's width, `NULL` dimmed.
struct DataGridRow: View {
    let row: ResultRow
    let columns: [ResultColumn]
    let widths: [Double]
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                Group {
                    if let value = row[column] {
                        Text(verbatim: value)
                    } else {
                        Text(verbatim: "NULL").foregroundStyle(.tertiary)
                    }
                }
                .font(Theme.Typography.cell)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, Theme.Spacing.s)
                .frame(width: widths.indices.contains(column.id) ? widths[column.id] : Theme.Layout.dataGridMinColumnWidth, alignment: .leading)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .dataGridRow(isSelected: isSelected, isHovered: isHovered, isStriped: row.id.isMultiple(of: 2) == false)
    }
}

#Preview {
    let result = QueryResult(columns: SampleCatalog.customerColumns, values: SampleCatalog.customerRows)
    VStack(spacing: 0) {
        ForEach(result.rows.prefix(4)) { row in
            DataGridRow(row: row, columns: result.columns, widths: result.columns.map { _ in 160 }, isSelected: row.id == 1, isHovered: row.id == 3)
        }
    }
    .padding()
}
