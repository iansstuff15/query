import SwiftUI

/// The Users & Permissions window's content: the connection it was opened for, or a note that
/// the connection has since closed.
struct UserManagementWindow: View {
    let sessionID: UUID?
    let registry: SessionRegistry

    var body: some View {
        if let session = sessionID.flatMap(registry.session) {
            UserManagementView(session: session)
                .id(session.id)
        } else {
            FallbackStateView(
                title: L10n.connectionClosedTitle, systemImage: "bolt.horizontal.circle",
                message: L10n.connectionClosedDetail, identifier: AccessibilityID.Users.closed
            )
            .frame(minWidth: Theme.Layout.usersWindowMinWidth, minHeight: Theme.Layout.usersWindowMinHeight)
        }
    }
}

#Preview {
    UserManagementWindow(sessionID: nil, registry: SessionRegistry())
}
