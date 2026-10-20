import SwiftUI

/// Search text field with a magnifying-glass icon and a clear button.
struct SearchField: View {
    enum Size {
        case regular
        case large
    }

    @Binding var text: String
    let prompt: LocalizedStringKey
    let hint: LocalizedStringKey
    let identifier: String
    var size: Size = .regular
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(size == .large ? Theme.Typography.paletteField : .body)
                .focused(isFocused)
                .accessibilityLabel(prompt)
                .accessibilityHint(hint)
                .accessibilityIdentifier(identifier)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Label(L10n.clear, systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(L10n.clear)
                .accessibilityIdentifier("\(identifier).clear")
            }
        }
        .padding(size == .large ? Theme.Spacing.m : Theme.Spacing.s)
        .background {
            if size == .regular {
                Capsule().fill(.fill.tertiary)
            }
        }
    }
}

#Preview {
    @Previewable @State var text = "ord"
    @Previewable @FocusState var focused: Bool
    SearchField(text: $text, prompt: L10n.sidebarSearchPrompt, hint: L10n.sidebarSearchHint, identifier: "preview", isFocused: $focused)
        .padding()
}
