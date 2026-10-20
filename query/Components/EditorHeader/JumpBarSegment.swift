import SwiftUI

/// One step of the jump bar's path. With choices it's a menu of its siblings (like Xcode's jump
/// bar); without, plain text. A chevron separates it from the next step.
struct JumpBarSegment: View {
    struct Choice: Identifiable {
        let id: String
        let title: String
        let systemImage: String
        let action: () -> Void
    }

    let title: Text
    let systemImage: String
    var choices: [Choice] = []
    var showsSeparator = true
    let identifier: String

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            if choices.isEmpty {
                label
                    .accessibilityIdentifier(identifier)
            } else {
                Menu {
                    ForEach(choices) { choice in
                        Button(action: choice.action) {
                            Label(choice.title, systemImage: choice.systemImage)
                        }
                    }
                } label: {
                    label
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(L10n.jumpBarHint)
                .accessibilityHint(L10n.jumpBarHint)
                .accessibilityIdentifier(identifier)
            }
            if showsSeparator {
                Image(systemName: "chevron.compact.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }

    private var label: some View {
        Label {
            title.lineLimit(1)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(.secondary)
        }
        .labelStyle(.titleAndIcon)
    }
}

#Preview {
    HStack {
        JumpBarSegment(title: Text(verbatim: "Local Postgres"), systemImage: "cylinder.split.1x2", identifier: "preview.0")
        JumpBarSegment(
            title: Text(verbatim: "public"), systemImage: "folder",
            choices: [.init(id: "sales", title: "sales", systemImage: "folder", action: {})], identifier: "preview.1"
        )
        JumpBarSegment(title: Text(verbatim: "customers"), systemImage: "tablecells", showsSeparator: false, identifier: "preview.2")
    }
    .padding()
}
