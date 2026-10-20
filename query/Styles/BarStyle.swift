import SwiftUI

/// A header or footer bar: padding and a solid background in the window's color (so content
/// scrolling beneath never shows through), with a divider on the side facing the content.
struct BarStyle: ViewModifier {
    /// Where the divider goes: `.top` for footers, `.bottom` for headers, `nil` for none.
    let divider: VerticalEdge?
    @Environment(\.barBackground) private var background

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(alignment: divider == .top ? .top : .bottom) {
                if divider != nil { Divider() }
            }
    }
}

extension View {
    func barStyle(divider: VerticalEdge? = nil) -> some View {
        modifier(BarStyle(divider: divider))
    }

    /// A solid bar background without padding, for bars with their own layout.
    func solidBarBackground() -> some View {
        modifier(SolidBarBackground())
    }
}

/// The bar background alone.
struct SolidBarBackground: ViewModifier {
    @Environment(\.barBackground) private var background

    func body(content: Content) -> some View {
        content.background(background)
    }
}
