import SwiftUI

/// One filter: enabled checkbox, column (or Any column), operator, value, clone and remove.
struct FilterRuleRow: View {
    @Binding var rule: FilterRule
    let index: Int
    let columns: [ColumnInfo]
    let onSubmit: () -> Void
    let onClone: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Toggle(L10n.enabled, isOn: $rule.isEnabled)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .accessibilityIdentifier(AccessibilityID.Filter.enabled(index))

            Picker(L10n.column, selection: $rule.column) {
                Text(L10n.anyColumn).tag(String?.none)
                Divider()
                ForEach(columns) { column in
                    Text(verbatim: column.name).tag(Optional(column.name))
                }
            }
            .labelsHidden()
            .frame(width: Theme.Layout.filterColumnWidth)
            .accessibilityLabel(L10n.column)
            .accessibilityIdentifier(AccessibilityID.Filter.column(index))

            Picker(L10n.filterOperator, selection: $rule.filterOperator) {
                ForEach(FilterOperator.allCases) { filterOperator in
                    Text(L10n.title(for: filterOperator)).tag(filterOperator)
                }
            }
            .labelsHidden()
            .frame(width: Theme.Layout.filterOperatorWidth)
            .accessibilityLabel(L10n.filterOperator)
            .accessibilityIdentifier(AccessibilityID.Filter.filterOperator(index))

            TextField(L10n.value, text: $rule.value)
                .textFieldStyle(.roundedBorder)
                .disabled(!rule.filterOperator.requiresValue)
                .onSubmit(onSubmit)
                .accessibilityLabel(L10n.value)
                .accessibilityHint(L10n.valueHint)
                .accessibilityIdentifier(AccessibilityID.Filter.value(index))

            Button(action: onClone) {
                Label(L10n.cloneFilter, systemImage: "plus.square.on.square")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help(L10n.cloneFilter)
            .accessibilityIdentifier(AccessibilityID.Filter.clone(index))

            Button(action: onRemove) {
                Label(L10n.removeFilter, systemImage: "minus.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help(L10n.removeFilter)
            .accessibilityIdentifier(AccessibilityID.Filter.remove(index))
        }
    }
}

#Preview {
    @Previewable @State var rule = FilterRule(column: "email", filterOperator: .contains, value: "example")
    FilterRuleRow(rule: $rule, index: 0, columns: SampleCatalog.customerColumns, onSubmit: {}, onClone: {}, onRemove: {})
        .padding()
}
