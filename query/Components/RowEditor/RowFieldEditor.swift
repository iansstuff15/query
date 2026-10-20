import SwiftUI

/// One column of the selected row: its name (with a key for primary-key columns and a dot once
/// changed), its type, and the value: in a text field with a NULL toggle when it can be edited,
/// or as plain, selectable text with a lock when it can't.
struct RowFieldEditor: View {
    @Binding var field: RowField
    let isKey: Bool
    let isEditable: Bool
    let onNullChange: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                if isKey {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.tint)
                        .help(L10n.rowKeyColumn)
                        .accessibilityLabel(L10n.rowKeyColumn)
                }
                Text(verbatim: field.column.name)
                    .font(.callout.weight(.medium))
                if field.isChanged {
                    Circle()
                        .fill(.tint)
                        .frame(width: Theme.Layout.changedDotSize, height: Theme.Layout.changedDotSize)
                        .accessibilityLabel(L10n.rowFieldChanged)
                }
                Spacer(minLength: Theme.Spacing.s)
                Text(verbatim: field.column.dataType)
                    .font(Theme.Typography.footer.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if isEditable {
                input
            } else {
                readOnlyValue
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var readOnlyValue: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Group {
                if let value = field.original {
                    Text(verbatim: value)
                } else {
                    Text(verbatim: "NULL").foregroundStyle(.tertiary)
                }
            }
            .font(Theme.Typography.cell)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "lock.fill")
                .font(Theme.Typography.footer)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.xs)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        .help(L10n.rowFieldReadOnly)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: field.column.name))
        .accessibilityValue(Text(verbatim: field.original ?? "NULL"))
        .accessibilityHint(L10n.rowFieldReadOnly)
        .accessibilityIdentifier(AccessibilityID.RowEditor.readOnly(field.column.name))
    }

    private var input: some View {
        HStack(spacing: Theme.Spacing.xs) {
            TextField(text: $field.text, prompt: field.isNull ? Text(verbatim: "NULL") : nil) {
                Text(verbatim: field.column.name)
            }
            .textFieldStyle(.roundedBorder)
            .font(Theme.Typography.cell)
            .labelsHidden()
            .disabled(!isEditable || field.isNull)
            .accessibilityLabel(Text(verbatim: field.column.name))
            .accessibilityIdentifier(AccessibilityID.RowEditor.field(field.column.name))
            Toggle(isOn: Binding(get: { field.isNull }, set: onNullChange)) {
                Text(verbatim: "NULL").font(Theme.Typography.footer.monospaced())
            }
            .toggleStyle(.button)
            .disabled(!isEditable)
            .help(L10n.rowNullHint)
            .accessibilityHint(L10n.rowNullHint)
            .accessibilityIdentifier(AccessibilityID.RowEditor.null(field.column.name))
        }
    }
}

#Preview {
    @Previewable @State var field = RowField(index: 0, column: ColumnInfo(name: "country", dataType: "text"), original: "GB")
    RowFieldEditor(field: $field, isKey: false, isEditable: true, onNullChange: { field.isNull = $0 })
        .frame(width: 320)
        .padding()
}
