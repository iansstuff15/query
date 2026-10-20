import SwiftUI

/// A selectable engine in the welcome grid.
struct EngineTile: View {
    let descriptor: EngineDescriptor
    let onSelect: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: Theme.Spacing.s) {
                Image(systemName: descriptor.systemImage)
                    .font(Theme.Typography.engineIcon)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text(verbatim: descriptor.displayName)
                    .font(Theme.Typography.engineName)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.engineTileHeight)
            .tileStyle(isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Motion.animation(Motion.highlight, reduceMotion: reduceMotion)) { isHovered = hovering }
        }
        .help(Text(verbatim: descriptor.displayName))
        .accessibilityLabel(Text(verbatim: descriptor.displayName))
        .accessibilityHint(L10n.engineHint)
        .accessibilityIdentifier(AccessibilityID.Welcome.engine(descriptor.engine.rawValue))
    }
}

#Preview {
    EngineTile(descriptor: EngineCatalog.descriptor(for: .postgreSQL), onSelect: {})
        .frame(width: 160)
        .padding()
}
