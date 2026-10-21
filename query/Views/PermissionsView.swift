import SwiftUI

/// The selected user's permissions: a row per schema (all its tables) and per table or view,
/// with a checkbox for SELECT, INSERT, UPDATE and DELETE. Save grants and revokes only what
/// changed.
struct PermissionsView: View {
    @Bindable var model: UserManagementViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(L10n.permissions).font(.headline)
                Text(model.isNewUser ? L10n.permissionsAfterCreate : L10n.permissionsDetail)
                    .font(Theme.Typography.footer)
                    .foregroundStyle(.secondary)
            }
            .barStyle(divider: .bottom)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            if model.selectedUser != nil {
                footer
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Users.permissions)
    }

    @ViewBuilder
    private var content: some View {
        if model.isNewUser {
            Color.clear
        } else {
            switch model.grantsState {
            case .idle, .loading:
                SkeletonTable(identifier: AccessibilityID.Users.permissionsSkeleton)
            case .failed:
                FallbackStateView(
                    title: L10n.usersLoadFailedTitle, systemImage: "lock.trianglebadge.exclamationmark",
                    message: L10n.usersLoadFailedDetail, identifier: AccessibilityID.Users.permissionsFailed
                )
            case .loaded:
                grid
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(model.targets) { target in
                        row(target)
                        Divider()
                    }
                } header: {
                    header
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text(L10n.permissionsObject)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(TablePrivilege.allCases) { privilege in
                Text(verbatim: privilege.rawValue)
                    .font(Theme.Typography.footer.monospaced().weight(.semibold))
                    .frame(width: Theme.Layout.permissionColumnWidth)
            }
        }
        .font(Theme.Typography.footer.weight(.semibold))
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .solidBarBackground()
        .overlay(alignment: .bottom) { Divider() }
    }

    private func row(_ target: GrantTarget) -> some View {
        HStack(spacing: 0) {
            Group {
                switch target {
                case .schema(let schema):
                    Label {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text(verbatim: schema).fontWeight(.semibold)
                            Text(L10n.permissionsAllTables).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "folder").foregroundStyle(.tint)
                    }
                case .table(_, let name):
                    Label {
                        Text(verbatim: name)
                    } icon: {
                        Image(systemName: "tablecells").foregroundStyle(.secondary)
                    }
                    .padding(.leading, Theme.Spacing.l)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(TablePrivilege.allCases) { privilege in
                PermissionCheckbox(
                    state: model.state(of: privilege, on: target),
                    label: Text(L10n.permissionLabel(privilege.rawValue, target.id)),
                    isEnabled: model.canEditPermissions,
                    identifier: AccessibilityID.Users.permission(privilege.rawValue, target.id)
                ) { granted in
                    model.set(privilege, on: target, granted: granted)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .contain)
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.s) {
            Group {
                switch model.permissionsSaveState {
                case .idle: EmptyView()
                case .saving: ProgressView().controlSize(.small)
                case .saved:
                    Label(L10n.rowSaved, systemImage: "checkmark.circle.fill").foregroundStyle(Theme.Palette.statusSuccess)
                case .failed(let message):
                    Label {
                        if let message { Text(verbatim: message) } else { Text(L10n.userSaveFailed) }
                    } icon: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .foregroundStyle(Theme.Palette.statusFailure)
                    .textSelection(.enabled)
                    .lineLimit(3)
                }
            }
            .font(Theme.Typography.footer)
            .accessibilityIdentifier(AccessibilityID.Users.permissionsStatus)
            Spacer()
            Button(action: model.revertPermissions) { Label(L10n.rowRevert, systemImage: "arrow.uturn.backward") }
                .buttonStyle(.glass)
                .disabled(!model.hasPermissionChanges)
                .accessibilityIdentifier(AccessibilityID.Users.revertPermissions)
            Button { Task { await model.savePermissions() } } label: {
                Label(L10n.savePermissions, systemImage: "lock.shield")
            }
            .buttonStyle(.glassProminent)
            .disabled(!model.hasPermissionChanges || model.permissionsSaveState == .saving)
            .help(L10n.savePermissionsHint)
            .accessibilityHint(L10n.savePermissionsHint)
            .accessibilityIdentifier(AccessibilityID.Users.savePermissions)
        }
        .barStyle(divider: .top)
    }
}

#Preview {
    let model = UserManagementViewModel(client: StubDatabaseClient())
    PermissionsView(model: model)
        .task {
            await model.load()
            model.selection = .user("query_reader")
        }
        .frame(width: 640, height: 520)
}
