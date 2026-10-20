import SwiftUI

/// A user's details: name, host (MySQL / MariaDB), password and options, with Save (or Create)
/// and Delete.
struct UserFormView: View {
    @Bindable var model: UserManagementViewModel
    let onDelete: (DatabaseUser) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField(text: $model.draft.name) { Text(L10n.userName) }
                        .accessibilityIdentifier(AccessibilityID.Users.name)
                    if model.capabilities.usesHosts {
                        TextField(text: $model.draft.host, prompt: Text(verbatim: "%")) { Text(L10n.userHost) }
                            .help(L10n.userHostHint)
                            .accessibilityHint(L10n.userHostHint)
                            .accessibilityIdentifier(AccessibilityID.Users.host)
                    }
                    SecureField(text: $model.draft.password, prompt: Text(model.isNewUser ? L10n.userPasswordNew : L10n.userPasswordKeep)) {
                        Text(L10n.userPassword)
                    }
                    .help(L10n.userPasswordHint)
                    .accessibilityHint(L10n.userPasswordHint)
                    .accessibilityIdentifier(AccessibilityID.Users.password)
                } header: {
                    Text(model.isNewUser ? L10n.newUser : L10n.userDetails)
                }
                Section {
                    ForEach(model.capabilities.options) { option in
                        Toggle(isOn: binding(for: option)) { Text(L10n.title(for: option)) }
                            .accessibilityIdentifier(AccessibilityID.Users.option(option.rawValue))
                    }
                } header: {
                    Text(L10n.userOptions)
                }
            }
            .formStyle(.grouped)
            footer
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            status
            HStack {
                if let user = model.selectedUser {
                    Button(role: .destructive) { onDelete(user) } label: {
                        Label(L10n.deleteUser, systemImage: "trash")
                    }
                    .buttonStyle(.glass)
                    .accessibilityIdentifier(AccessibilityID.Users.delete)
                }
                Spacer()
                Button { Task { await model.saveUser() } } label: {
                    Label(model.isNewUser ? L10n.createUser : L10n.saveUser, systemImage: "person.crop.circle.badge.checkmark")
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!model.canSaveUser)
                .help(L10n.saveUserHint)
                .accessibilityHint(L10n.saveUserHint)
                .accessibilityIdentifier(AccessibilityID.Users.save)
            }
        }
        .barStyle(divider: .top)
    }

    @ViewBuilder
    private var status: some View {
        Group {
            if let error = model.formError {
                Label(L10n.message(for: error), systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(Theme.Palette.statusFailure)
            } else {
                switch model.userSaveState {
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
                }
            }
        }
        .font(Theme.Typography.footer)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier(AccessibilityID.Users.status)
    }

    private func binding(for option: UserOption) -> Binding<Bool> {
        Binding(
            get: { model.draft.options.contains(option) },
            set: { isOn in
                if isOn { model.draft.options.insert(option) } else { model.draft.options.remove(option) }
            }
        )
    }
}

#Preview {
    let model = UserManagementViewModel(client: StubDatabaseClient())
    UserFormView(model: model, onDelete: { _ in })
        .task {
            await model.load()
            model.startNewUser()
        }
        .frame(width: 360, height: 520)
}
