import SwiftUI

/// Padding for content placed in a `safeAreaBar`. No background: the system draws the
/// Liquid Glass scroll edge effect behind bars.
struct BarStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func barStyle() -> some View {
        modifier(BarStyle())
    }
}
