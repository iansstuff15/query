import SwiftUI

/// The connection popup for one engine: optional connection-string import (applied as it's typed,
/// or picked up from the clipboard on open), the engine's fields, and Test / Connect.
struct ConnectionSheet: View {
    @Bindable var model: ConnectionFormViewModel
    let onConnected: (ConnectionSession) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            if let example = model.descriptor.urlExample {
                urlSection(example: example)
            }
            Section {
                TextField(text: $model.name, prompt: Text(verbatim: model.displayName)) { Text(L10n.title(for: .name)) }
                    .accessibilityIdentifier(AccessibilityID.Connection.field(ConnectionField.name.rawValue))
                ForEach(model.visibleFields) { field in
                    ConnectionFieldRow(
                        field: field,
                        value: $model.draft[field],
                        placeholder: model.descriptor.defaultValues[field] ?? "",
                        onPickFile: model.setFile
                    )
                }
                if model.descriptor.fields.contains(where: \.isSecret) {
                    Toggle(L10n.rememberSecrets, isOn: $model.rememberSecrets)
                        .accessibilityIdentifier(AccessibilityID.Connection.remember)
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaBar(edge: .top) { header }
        .safeAreaBar(edge: .bottom) { footer }
        .frame(width: Theme.Layout.connectionSheetWidth)
        .frame(minHeight: Theme.Layout.connectionSheetMinHeight)
        .accessibilityIdentifier(AccessibilityID.Connection.sheet)
        .task { model.pickUpClipboard() }
    }

    private var header: some View {
        Label {
            Text(verbatim: model.descriptor.displayName).font(.title2)
        } icon: {
            Image(systemName: model.descriptor.systemImage).foregroundStyle(.tint).accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.l)
    }

    @ViewBuilder
    private func urlSection(example: String) -> some View {
        Section {
            HStack {
                TextField(text: $model.connectionStringInput, prompt: Text(verbatim: example)) {
                    Text(L10n.connectionString)
                }
                .onSubmit(model.importConnectionString)
                .accessibilityHint(L10n.connectionStringHint)
                .accessibilityIdentifier(AccessibilityID.Connection.connectionString)
                Button(action: model.importConnectionString) { Label(L10n.importURL, systemImage: "square.and.arrow.down") }
                    .buttonStyle(.glass)
                    .help(L10n.connectionStringHint)
                    .accessibilityIdentifier(AccessibilityID.Connection.importURL)
            }
        } footer: {
            switch model.importResult {
            case .none: EmptyView()
            case .imported: Text(L10n.importSucceeded).foregroundStyle(.secondary)
            case .pasted: Text(L10n.importFromClipboard).foregroundStyle(.secondary)
            case .invalid: Text(L10n.importUnrecognized).foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        HStack {
            ConnectionStatusView(state: model.testState)
            Spacer()
            Button(role: .cancel) { dismiss() } label: { Text(L10n.cancel) }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier(AccessibilityID.Connection.cancel)
            Button(action: model.save) {
                Label(L10n.save, systemImage: model.didSave ? "checkmark" : "square.and.arrow.down.on.square")
            }
            .buttonStyle(.glass)
            .disabled(!model.canConnect)
            .help(L10n.saveHint)
            .accessibilityHint(L10n.saveHint)
            .accessibilityIdentifier(AccessibilityID.Connection.save)
            Button { Task { await model.test() } } label: { Label(L10n.test, systemImage: "bolt") }
                .buttonStyle(.glass)
                .disabled(!model.canConnect || model.testState.isLoading)
                .help(L10n.testHint)
                .accessibilityIdentifier(AccessibilityID.Connection.test)
            Button {
                Task {
                    if let session = await model.connect() {
                        onConnected(session)
                        dismiss()
                    }
                }
            } label: {
                Label(L10n.connect, systemImage: "powerplug")
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canConnect || model.isConnecting)
            .help(L10n.connectHint)
            .accessibilityIdentifier(AccessibilityID.Connection.connect)
        }
        .padding(Theme.Spacing.l)
    }
}

#Preview {
    ConnectionSheet(
        model: ConnectionFormViewModel(engine: .postgreSQL, factory: StubDatabaseClientFactory(), store: PreviewConnectionStore()),
        onConnected: { _ in }
    )
}
