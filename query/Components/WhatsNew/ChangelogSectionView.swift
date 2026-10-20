import SwiftUI

/// One category of a release (New Features, UI Changes, Bug Fixes, …): a colored heading with
/// a count, then each change as a bullet with inline Markdown.
struct ChangelogSectionView: View {
    let section: ChangelogRelease.Section
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: section.category.systemImage)
                    .foregroundStyle(Theme.Palette.changelog(section.category))
                    .frame(width: Theme.Layout.changelogIconWidth)
                    .accessibilityHidden(true)
                L10n.title(for: section.category)
                    .font(.headline)
                Text(section.items.count, format: .number)
                    .font(Theme.Typography.footer)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .background(.fill.tertiary, in: Capsule())
                    .accessibilityLabel(L10n.changeCount(section.items.count))
            }
            ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text(verbatim: "•")
                        .foregroundStyle(Theme.Palette.changelog(section.category))
                        .frame(width: Theme.Layout.changelogIconWidth)
                        .accessibilityHidden(true)
                    Text(Self.markdown(item))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

#Preview {
    ChangelogSectionView(
        section: .init(category: .bugFixes, items: ["MySQL `DATETIME` values showed as **garbled** bytes.", "Another fix."]),
        identifier: "preview"
    )
    .frame(width: 520)
    .padding()
}
