import SwiftUI

/// Background for a palette row in its highlighted / hovered / idle state.
struct PaletteRowStyle: ViewModifier {
    let isHighlighted: Bool
    let isHovered: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(isHighlighted ? AnyShapeStyle(.tint.opacity(0.25)) : (isHovered ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.clear)))
            }
            .contentShape(Rectangle())
    }
}

extension View {
    func paletteRow(isHighlighted: Bool, isHovered: Bool) -> some View {
        modifier(PaletteRowStyle(isHighlighted: isHighlighted, isHovered: isHovered))
    }
}
