import SwiftUI

/// One column of the selected row: its name (with a key for primary-key columns and a dot once
/// changed), its type, the value in a text field, and a NULL toggle.
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
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    @Previewable @State var field = RowField(index: 0, column: ColumnInfo(name: "country", dataType: "text"), original: "GB")
    RowFieldEditor(field: $field, isKey: false, isEditable: true, onNullChange: { field.isNull = $0 })
        .frame(width: 320)
        .padding()
}
