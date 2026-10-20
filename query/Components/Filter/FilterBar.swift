import SwiftUI

/// TablePlus-style filter bar: a list of rules, the generated SQL, and Apply / Clear.
struct FilterBar: View {
    @Binding var rules: [FilterRule]
    let columns: [ColumnInfo]
    let preview: String?
    let onApply: () -> Void
    let onAdd: () -> Void
    let onClear: () -> Void
    let onClone: (FilterRule.ID) -> Void
    let onRemove: (FilterRule.ID) -> Void
    @FocusedValue(\.isEditingSQL) private var isEditingSQL

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ForEach(Array($rules.enumerated()), id: \.element.id) { index, $rule in
                FilterRuleRow(
                    rule: $rule,
                    index: index,
                    columns: columns,
                    onSubmit: onApply,
                    onClone: { onClone(rule.id) },
                    onRemove: { onRemove(rule.id) }
                )
            }
            HStack(spacing: Theme.Spacing.s) {
                Button(action: onAdd) {
                    Label(L10n.addFilter, systemImage: "plus")
                }
                .buttonStyle(.glass)
                .help(L10n.addFilter)
                .accessibilityIdentifier(AccessibilityID.Filter.add)

                Text(verbatim: preview ?? "")
                    .font(Theme.Typography.sql)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(Text(verbatim: preview ?? ""))
                    .accessibilityLabel(L10n.generatedSQL)
                    .accessibilityValue(Text(verbatim: preview ?? ""))
                    .accessibilityIdentifier(AccessibilityID.Filter.sqlPreview)

                Button(action: onClear) {
                    Label(L10n.clear, systemImage: "xmark")
                }
                .buttonStyle(.glass)
                .help(L10n.clearHint)
                .accessibilityHint(L10n.clearHint)
                .accessibilityIdentifier(AccessibilityID.Filter.clear)

                Button(action: onApply) {
                    Label(L10n.apply, systemImage: "line.3.horizontal.decrease")
                }
                .keyboardShortcut(isEditingSQL == true ? nil : KeyboardShortcut(.return, modifiers: .command))
                .buttonStyle(.glassProminent)
                .help(L10n.applyHint)
                .accessibilityHint(L10n.applyHint)
                .accessibilityIdentifier(AccessibilityID.Filter.apply)
            }
        }
        .barStyle(divider: .bottom)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Filter.bar)
    }

}

#Preview {
    @Previewable @State var rules = [FilterRule(column: "email", filterOperator: .contains, value: "example")]
    let object = SampleCatalog.objects[2]
    FilterBar(
        rules: $rules,
        columns: SampleCatalog.customerColumns,
        preview: SQLPreview.text(RowFilterQuery(object: object, columns: SampleCatalog.customerColumns, rules: rules, limit: 300).statement()),
        onApply: {}, onAdd: {}, onClear: {}, onClone: { _ in }, onRemove: { _ in }
    )
    .frame(width: 900)
}
