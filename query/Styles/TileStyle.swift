import SwiftUI

/// Card look for engine tiles. Tiles are content, so they use a quiet system fill rather than
/// Liquid Glass (glass is reserved for the functional layer). Corners follow the container.
struct TileStyle: ViewModifier {
    let isHovered: Bool

    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.m)
            .background(isHovered ? AnyShapeStyle(.fill.secondary) : AnyShapeStyle(.fill.quaternary), in: .rect(cornerRadius: Theme.Radius.large))
            .contentShape(.rect(cornerRadius: Theme.Radius.large))
    }
}

extension View {
    func tileStyle(isHovered: Bool) -> some View {
        modifier(TileStyle(isHovered: isHovered))
    }
}
