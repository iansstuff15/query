import SwiftUI

/// The Users & Permissions window for one connection: users in the sidebar (+ to add, right-
/// click to delete), and for the selected or new user, its details and its table permissions.
struct UserManagementView: View {
    @State private var model: UserManagementViewModel
    @State private var pendingDeletion: DatabaseUser?
    private let connectionName: String

    init(session: ConnectionSession) {
        _model = State(initialValue: UserManagementViewModel(client: session.client))
        connectionName = session.name
    }

    var body: some View {
        Group {
            if model.isSupported {
                NavigationSplitView {
                    sidebar
                        .navigationSplitViewColumnWidth(min: Theme.Layout.sidebarMinWidth, ideal: Theme.Layout.sidebarIdealWidth)
                } detail: {
                    detail
                }
            } else {
                FallbackStateView(
                    title: L10n.usersUnavailableTitle, systemImage: "person.2.slash",
                    message: L10n.usersUnavailableDetail, identifier: AccessibilityID.Users.unavailable
                )
            }
        }
        .navigationTitle(Text(L10n.usersWindowTitle))
        .navigationSubtitle(Text(verbatim: connectionName))
        .task { await model.load() }
        .confirmationDialog(
            pendingDeletion.map { L10n.deleteUserConfirmTitle($0.name) } ?? L10n.deleteUser,
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { user in
            Button(role: .destructive) { Task { await model.deleteUser(user) } } label: { Text(L10n.deleteUser) }
                .accessibilityIdentifier(AccessibilityID.Users.confirmDelete)
            Button(role: .cancel) {} label: { Text(L10n.cancel) }
        } message: { _ in
            Text(L10n.deleteUserConfirmDetail)
        }
        .frame(minWidth: Theme.Layout.usersWindowMinWidth, minHeight: Theme.Layout.usersWindowMinHeight)
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        switch model.usersState {
        case .idle, .loading:
            SkeletonTable(rows: Theme.Layout.skeletonRows / 2, columns: 1, identifier: AccessibilityID.Users.skeleton)
        case .failed:
            FallbackStateView(
                title: L10n.usersLoadFailedTitle, systemImage: "person.crop.circle.badge.exclamationmark",
                message: L10n.usersLoadFailedDetail, identifier: AccessibilityID.Users.loadFailed
            )
        case .loaded(let users):
            List(selection: $model.selection) {
                ForEach(users) { user in
                    UserListRow(user: user)
                        .tag(UserManagementViewModel.Selection.user(user.id))
                        .contextMenu {
                            Button(role: .destructive) { pendingDeletion = user } label: {
                                Label(L10n.deleteUser, systemImage: "trash")
                            }
                        }
                }
            }
            .accessibilityIdentifier(AccessibilityID.Users.list)
            .toolbar {
                ToolbarItem {
                    Button(action: model.startNewUser) {
                        Label(L10n.newUser, systemImage: "person.badge.plus")
                    }
                    .help(L10n.newUserHint)
                    .accessibilityIdentifier(AccessibilityID.Users.newUser)
                }
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if model.selection == nil {
            FallbackStateView(
                title: L10n.noUserSelectedTitle, systemImage: "person.crop.circle",
                message: L10n.noUserSelectedDetail, identifier: AccessibilityID.Users.placeholder
            )
        } else {
            HStack(spacing: 0) {
                UserFormView(model: model) { pendingDeletion = $0 }
                    .frame(width: Theme.Layout.userFormWidth)
                Divider()
                PermissionsView(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

#Preview {
    UserManagementView(session: ConnectionSession(id: UUID(), name: "Local Postgres", engine: .postgreSQL, client: StubDatabaseClient()))
        .frame(width: 1000, height: 640)
}
