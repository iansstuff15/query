import SwiftUI

/// One cell of the permissions grid: on, off, or mixed (some tables of a schema).
struct PermissionCheckbox: View {
    let state: UserManagementViewModel.CheckState
    let label: Text
    let isEnabled: Bool
    let identifier: String
    let onChange: (Bool) -> Void

    var body: some View {
        Button { onChange(state != .on) } label: {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(state == .off ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                .frame(width: Theme.Layout.permissionColumnWidth)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityAddTraits(state == .on ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private var symbol: String {
        switch state {
        case .on: "checkmark.square.fill"
        case .off: "square"
        case .mixed: "minus.square.fill"
        }
    }

    private var value: Text {
        switch state {
        case .on: Text(L10n.permissionGranted)
        case .off: Text(L10n.permissionNotGranted)
        case .mixed: Text(L10n.permissionSomeTables)
        }
    }
}

#Preview {
    HStack {
        PermissionCheckbox(state: .on, label: Text(verbatim: "SELECT"), isEnabled: true, identifier: "a", onChange: { _ in })
        PermissionCheckbox(state: .mixed, label: Text(verbatim: "INSERT"), isEnabled: true, identifier: "b", onChange: { _ in })
        PermissionCheckbox(state: .off, label: Text(verbatim: "UPDATE"), isEnabled: true, identifier: "c", onChange: { _ in })
    }
    .padding()
}
