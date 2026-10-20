import AppKit
import SwiftUI

/// Rows as a grid where each row is a button: click one to select it, and the selected row stays
/// highlighted (accent tint and border) even when another panel has focus, unlike `Table`, whose
/// unfocused selection is a faint gray. After a click, arrow keys move the selection and Esc
/// clears it.
struct DataGrid: View {
    let result: QueryResult
    @Binding var selection: ResultRow.ID?
    var identifier = AccessibilityID.Detail.results
    @State private var hoveredRowID: ResultRow.ID?
    @FocusState private var isFocused: Bool

    var body: some View {
        let fitted = ColumnWidths.widths(
            for: result, characterWidth: Self.characterWidth, padding: Theme.Spacing.s * 2 + Theme.Spacing.xs,
            range: Theme.Layout.dataGridMinColumnWidth...Theme.Layout.dataGridMaxColumnWidth
        )
        // Fill the panel like a native table: content starts at the top leading corner (a
        // two-way scroll view would otherwise center narrow content), and spare width is shared
        // among the columns.
        GeometryReader { viewport in
            let widths = ColumnWidths.filling(fitted, to: viewport.size.width - Theme.Spacing.xs * 2)
            ScrollViewReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(result.rows) { row in
                                // A button, so a click always selects (no gesture recognition to
                                // compete with scrolling or focus).
                                Button { select(row.id) } label: {
                                    DataGridRow(
                                        row: row, columns: result.columns, widths: widths,
                                        isSelected: row.id == selection, isHovered: row.id == hoveredRowID
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(row.id)
                                .onHover { inside in
                                    if inside { hoveredRowID = row.id } else if hoveredRowID == row.id { hoveredRowID = nil }
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(row.id == selection ? [.isButton, .isSelected] : .isButton)
                                .accessibilityHint(L10n.rowSelectHint)
                                .accessibilityAction { select(row.id) }
                                .accessibilityIdentifier("\(identifier).row.\(row.id)")
                            }
                        } header: {
                            header(widths: widths)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xs)
                    .frame(minWidth: viewport.size.width, minHeight: viewport.size.height, alignment: .topLeading)
                }
                // Focus only for keyboard input, so clicks go to the rows instead of focusing the grid.
                .focusable(interactions: .edit)
                .focused($isFocused)
                .focusEffectDisabled()
                .onKeyPress(.downArrow) { move(by: 1, proxy: proxy) }
                .onKeyPress(.upArrow) { move(by: -1, proxy: proxy) }
                .onKeyPress(.escape) {
                    selection = nil
                    return .handled
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func header(widths: [Double]) -> some View {
        HStack(spacing: 0) {
            ForEach(result.columns) { column in
                Text(verbatim: column.name)
                    .font(Theme.Typography.cell.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, Theme.Spacing.s)
                    .frame(width: widths.indices.contains(column.id) ? widths[column.id] : Theme.Layout.dataGridMinColumnWidth, alignment: .leading)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .solidBarBackground()
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityAddTraits(.isHeader)
    }

    private func select(_ id: ResultRow.ID) {
        selection = id
        isFocused = true
    }

    private func move(by offset: Int, proxy: ScrollViewProxy) -> KeyPress.Result {
        guard !result.rows.isEmpty else { return .ignored }
        let current = selection.flatMap { id in result.rows.firstIndex { $0.id == id } }
        let next = min(max((current ?? (offset > 0 ? -1 : result.rows.count)) + offset, 0), result.rows.count - 1)
        let id = result.rows[next].id
        selection = id
        proxy.scrollTo(id)
        return .handled
    }

    /// One character of the grid's monospaced font.
    private static var characterWidth: Double {
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        return ("0" as NSString).size(withAttributes: [.font: font]).width
    }
}

#Preview {
    @Previewable @State var selection: ResultRow.ID? = 2
    DataGrid(result: QueryResult(columns: SampleCatalog.customerColumns, values: SampleCatalog.customerRows), selection: $selection)
        .frame(width: 800, height: 400)
}
