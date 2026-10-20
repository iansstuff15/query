import SwiftUI

/// An editor tab's look: the active tab sits on the editor's background with an accent rule
/// along its top edge, like Xcode; others are recessed and lighten on hover.
struct EditorTabStyle: ViewModifier {
    let isActive: Bool
    let isHovered: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .frame(minWidth: Theme.Layout.editorTabMinWidth, maxWidth: Theme.Layout.editorTabMaxWidth)
            .background(background)
            .overlay(alignment: .top) {
                if isActive {
                    Rectangle().fill(.tint).frame(height: Theme.Layout.editorTabIndicatorHeight)
                }
            }
            .overlay(alignment: .trailing) {
                Divider()
            }
            .contentShape(Rectangle())
    }

    private var background: AnyShapeStyle {
        if isActive { return AnyShapeStyle(.background) }
        return isHovered ? AnyShapeStyle(.fill.secondary) : AnyShapeStyle(.fill.quaternary)
    }
}

extension View {
    func editorTab(isActive: Bool, isHovered: Bool) -> some View {
        modifier(EditorTabStyle(isActive: isActive, isHovered: isHovered))
    }
}
