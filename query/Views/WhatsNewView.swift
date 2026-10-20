import SwiftUI

/// "What's New" sheet: a release from CHANGELOG.md, its changes grouped by category, and a
/// version menu to read earlier releases.
struct WhatsNewView: View {
    @Bindable var model: WhatsNewViewModel
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(width: Theme.Layout.whatsNewWidth, height: Theme.Layout.whatsNewHeight)
        .accessibilityIdentifier(AccessibilityID.WhatsNew.sheet)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(L10n.whatsNewTitle).font(.largeTitle.bold())
                if let release = model.selectedRelease {
                    Group {
                        if let date = release.date {
                            Text(L10n.releaseVersionDate(release.version, date))
                        } else {
                            Text(L10n.releaseVersion(release.version))
                        }
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityID.WhatsNew.version)
                }
            }
            Spacer()
            if model.releases.count > 1 {
                Picker(selection: $model.selectedVersion) {
                    ForEach(model.releases) { release in
                        Text(L10n.releaseVersion(release.version)).tag(Optional(release.version))
                    }
                } label: {
                    Text(L10n.releaseNotesVersion)
                }
                .pickerStyle(.menu)
                .fixedSize()
                .help(L10n.releaseNotesVersionHint)
                .accessibilityIdentifier(AccessibilityID.WhatsNew.versionPicker)
            }
        }
        .padding(Theme.Spacing.l)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            SkeletonTable(rows: Theme.Layout.skeletonRows / 2, columns: 1, identifier: AccessibilityID.WhatsNew.skeleton)
        case .loaded where model.selectedRelease != nil:
            if let release = model.selectedRelease {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        ForEach(release.sections) { section in
                            ChangelogSectionView(section: section, identifier: AccessibilityID.WhatsNew.section(section.category))
                        }
                    }
                    .padding(Theme.Spacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(release.id)
            }
        case .loaded, .failed:
            FallbackStateView(
                title: L10n.noReleaseNotes, systemImage: "doc.text",
                message: L10n.noReleaseNotesDetail, identifier: AccessibilityID.WhatsNew.empty
            )
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(action: onDone) {
                Label(L10n.whatsNewContinue, systemImage: "checkmark")
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier(AccessibilityID.WhatsNew.done)
        }
        .padding(Theme.Spacing.l)
    }
}

#Preview {
    let model = WhatsNewViewModel(provider: StaticChangelogProvider(markdown: """
    ## [0.2.0] - 2026-10-20
    ### New Features
    - **Clipboard** connection strings fill in the sheet.
    ### UI Changes
    - Green and red test results.
    ### Bug Fixes
    - MySQL `DATETIME` values were garbled.
    ## [0.1.0] - 2026-10-17
    ### Added
    - First release.
    """))
    WhatsNewView(model: model, onDone: {})
        .task { await model.load() }
}
