import SwiftUI

/// A data grid row's background: the selected row is tinted with the accent color and outlined
/// with an accent border (visible whether or not the grid has focus); hovered rows lighten, and
/// every other row is lightly striped.
struct DataGridRowStyle: ViewModifier {
    let isSelected: Bool
    let isHovered: Bool
    let isStriped: Bool

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(fill)
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .strokeBorder(.tint, lineWidth: Theme.Layout.selectedRowBorderWidth)
                }
            }
            .contentShape(Rectangle())
    }

    private var fill: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(.tint.opacity(Theme.Opacity.selectedRow)) }
        if isHovered { return AnyShapeStyle(.fill.tertiary) }
        return isStriped ? AnyShapeStyle(.fill.quinary) : AnyShapeStyle(.clear)
    }
}

extension View {
    func dataGridRow(isSelected: Bool, isHovered: Bool, isStriped: Bool) -> some View {
        modifier(DataGridRowStyle(isSelected: isSelected, isHovered: isHovered, isStriped: isStriped))
    }
}
