import SwiftUI

/// A saved connection in the welcome screen's recent column. Clicking connects straight away
/// (disabled when the background check couldn't reach it); the trailing pencil edits it.
struct RecentConnectionRow: View {
    let name: String
    let engine: DatabaseEngine
    let health: ConnectionHealth
    let isConnecting: Bool
    let identifier: String
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    private var canOpen: Bool { health.canOpen && !isConnecting }

    var body: some View {
        let descriptor = EngineCatalog.descriptor(for: engine)
        HStack(spacing: Theme.Spacing.s) {
            Button(action: onOpen) {
                Label {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(verbatim: name)
                            .foregroundStyle(health.canOpen ? .primary : .secondary)
                        Text(verbatim: descriptor.displayName)
                            .font(Theme.Typography.footer)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: descriptor.systemImage)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canOpen)
            .help(health.canOpen ? L10n.recentHint : L10n.connectionUnreachableHelp)
            .accessibilityHint(health.canOpen ? L10n.recentHint : L10n.connectionUnreachableHelp)
            .accessibilityIdentifier(identifier)

            ConnectionHealthBadge(health: health, isConnecting: isConnecting, identifier: "\(identifier).status")

            Button(action: onEdit) {
                Label(L10n.editConnection, systemImage: "pencil")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help(L10n.editConnectionHint)
            .accessibilityHint(L10n.editConnectionHint)
            .accessibilityIdentifier("\(identifier).edit")
        }
        .paletteRow(isHighlighted: false, isHovered: isHovered && canOpen)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(action: onOpen) { Label(L10n.open, systemImage: "arrow.right.circle") }
                .disabled(!canOpen)
            Button(action: onEdit) { Label(L10n.editConnection, systemImage: "pencil") }
            Divider()
            Button(role: .destructive, action: onDelete) { Label(L10n.deleteConnection, systemImage: "trash") }
        }
    }
}

#Preview {
    VStack {
        RecentConnectionRow(
            name: "Local Postgres", engine: .postgreSQL, health: .reachable, isConnecting: false, identifier: "preview.0",
            onOpen: {}, onEdit: {}, onDelete: {}
        )
        RecentConnectionRow(
            name: "Staging MySQL", engine: .mySQL, health: .unreachable, isConnecting: false, identifier: "preview.1",
            onOpen: {}, onEdit: {}, onDelete: {}
        )
    }
    .frame(width: 300)
    .padding()
}
