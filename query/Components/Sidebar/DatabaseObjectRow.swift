import SwiftUI

/// Sidebar row for a table or view; draggable as its qualified name.
struct DatabaseObjectRow: View {
    let object: DatabaseObject
    let onOpen: () -> Void
    let onOpenWithFilters: () -> Void

    var body: some View {
        Label {
            Text(verbatim: object.name)
        } icon: {
            Image(systemName: object.kind.systemImage)
                .accessibilityHidden(true)
        }
        .draggable(object.id)
        .contextMenu {
            Button(action: onOpen) { Label(L10n.open, systemImage: "arrow.right.circle") }
            Button(action: onOpenWithFilters) { Label(L10n.openWithFilters, systemImage: "line.3.horizontal.decrease.circle") }
        }
        .accessibilityLabel(Text(verbatim: object.name))
        .accessibilityValue(Text(L10n.title(for: object.kind)))
        .accessibilityHint(L10n.objectRowHint)
        .accessibilityIdentifier(AccessibilityID.Sidebar.row(object.id))
    }
}

#Preview {
    List {
        DatabaseObjectRow(object: SampleCatalog.objects[2], onOpen: {}, onOpenWithFilters: {})
        DatabaseObjectRow(object: SampleCatalog.objects[6], onOpen: {}, onOpenWithFilters: {})
    }
}
