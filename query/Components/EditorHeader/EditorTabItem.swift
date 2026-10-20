import SwiftUI

/// One tab in the center panel's tab bar: icon and title, with a close button that appears on
/// hover (or on the active tab), at the leading edge like Xcode.
struct EditorTabItem: View {
    let title: Text
    let systemImage: String
    let isActive: Bool
    let identifier: String
    let onSelect: () -> Void
    let onClose: () -> Void
    let onCloseOthers: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Button(action: onClose) {
                Label(L10n.closeTab, systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(Theme.Typography.footer)
            }
            .buttonStyle(.borderless)
            .opacity(isHovered || isActive ? 1 : 0)
            .help(L10n.closeTab)
            .accessibilityIdentifier("\(identifier).close")

            Button(action: onSelect) {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: systemImage)
                        .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .accessibilityHidden(true)
                    title
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(isActive ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isActive ? [.isSelected] : [])
            .accessibilityHint(L10n.tabHint)
            .accessibilityIdentifier(identifier)
        }
        .font(Theme.Typography.editorTab)
        .editorTab(isActive: isActive, isHovered: isHovered)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(action: onClose) { Label(L10n.closeTab, systemImage: "xmark") }
            Button(action: onCloseOthers) { Label(L10n.closeOtherTabs, systemImage: "xmark.square") }
        }
    }
}

#Preview {
    HStack(spacing: 0) {
        EditorTabItem(
            title: Text(verbatim: "customers"), systemImage: "tablecells", isActive: true, identifier: "preview.0",
            onSelect: {}, onClose: {}, onCloseOthers: {}
        )
        EditorTabItem(
            title: Text(verbatim: "orders"), systemImage: "tablecells", isActive: false, identifier: "preview.1",
            onSelect: {}, onClose: {}, onCloseOthers: {}
        )
    }
    .padding()
}
