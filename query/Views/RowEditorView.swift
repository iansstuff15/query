import SwiftUI

/// The right panel's Row tab: the selected row's fields as text fields holding its values, and
/// Save, which updates that row in the database.
struct RowEditorView: View {
    @Bindable var model: RowEditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    ForEach($model.fields) { $field in
                        RowFieldEditor(
                            field: $field, isKey: model.keyColumns?.contains(field.column.name) == true, isEditable: model.canEdit,
                            onNullChange: { model.setNull($0, for: field.id) }
                        )
                    }
                }
                .padding(Theme.Spacing.m)
            }
            Divider()
            footer
        }
        .task(id: model.rowID) { await model.loadKey() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.RowEditor.panel)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Label {
                Text(verbatim: model.object.name).font(.headline)
            } icon: {
                Image(systemName: model.object.kind.systemImage).foregroundStyle(.tint)
            }
            Group {
                if !model.canEdit {
                    Text(L10n.rowReadOnly)
                } else if let keys = model.keyColumns {
                    Text(keys.isEmpty ? L10n.rowMatchedByAll : L10n.rowMatchedByKey(keys.joined(separator: ", ")))
                }
            }
            .font(Theme.Typography.footer)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.s) {
            status
            Spacer(minLength: 0)
            Button(action: model.revert) {
                Text(L10n.rowRevert)
            }
            .buttonStyle(.glass)
            .disabled(!model.hasChanges || model.saveState == .saving)
            .help(L10n.rowRevertHint)
            .accessibilityHint(L10n.rowRevertHint)
            .accessibilityIdentifier(AccessibilityID.RowEditor.revert)
            Button { Task { await model.save() } } label: {
                Label(L10n.rowSave, systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!model.canSave)
            .help(L10n.rowSaveHint)
            .accessibilityHint(L10n.rowSaveHint)
            .accessibilityIdentifier(AccessibilityID.RowEditor.save)
        }
        .padding(Theme.Spacing.m)
    }

    @ViewBuilder
    private var status: some View {
        Group {
            switch model.saveState {
            case .idle:
                EmptyView()
            case .saving:
                HStack(spacing: Theme.Spacing.xs) {
                    ProgressView().controlSize(.small)
                    Text(L10n.rowSaving)
                }
                .foregroundStyle(.secondary)
            case .saved:
                Label(L10n.rowSaved, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Palette.statusSuccess)
            case .failed(let message):
                Group {
                    if let message {
                        Label(message, systemImage: "xmark.circle.fill")
                    } else {
                        Label(L10n.rowSaveFailed, systemImage: "xmark.circle.fill")
                    }
                }
                .foregroundStyle(Theme.Palette.statusFailure)
                .textSelection(.enabled)
                .lineLimit(3)
            }
        }
        .font(Theme.Typography.footer)
        .accessibilityIdentifier(AccessibilityID.RowEditor.status)
    }
}

#Preview {
    let row = ResultRow(id: 0, values: SampleCatalog.customerRows[0])
    RowEditorView(model: RowEditorViewModel(
        object: SampleCatalog.objects[2], columns: SampleCatalog.customerColumns, row: row, client: StubDatabaseClient()
    ))
    .frame(width: 380, height: 600)
}
