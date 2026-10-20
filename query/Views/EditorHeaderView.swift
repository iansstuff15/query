import SwiftUI

/// The center panel's header, organized like Xcode's editor: a tab bar of open tables (and the
/// SQL results), then a jump bar with back / forward and the path connection › schema › object,
/// where each step is a menu of its siblings.
struct EditorHeaderView: View {
    @Bindable var model: WorkspaceViewModel
    let session: ConnectionSession

    var body: some View {
        VStack(spacing: 0) {
            if !model.tabs.isEmpty {
                tabBar
                Divider()
            }
            jumpBar
            Divider()
        }
        .solidBarBackground()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Editor.header)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(Array(model.tabs.enumerated()), id: \.element) { index, tab in
                    EditorTabItem(
                        title: title(for: tab), systemImage: systemImage(for: tab), isActive: tab == model.activeTab,
                        identifier: AccessibilityID.Editor.tab(index),
                        onSelect: { model.activate(tab) },
                        onClose: { model.closeTab(tab) },
                        onCloseOthers: { model.closeOtherTabs(than: tab) }
                    )
                }
            }
        }
        .scrollIndicators(.never)
        .accessibilityIdentifier(AccessibilityID.Editor.tabBar)
    }

    private func title(for tab: WorkspaceTab) -> Text {
        switch tab {
        case .object(let id): Text(verbatim: model.object(for: tab)?.name ?? id)
        case .query(let key): Text(verbatim: key)
        }
    }

    private func systemImage(for tab: WorkspaceTab) -> String {
        switch tab {
        case .object: model.object(for: tab)?.kind.systemImage ?? "tablecells"
        case .query: "terminal"
        }
    }

    // MARK: - Jump bar

    private var jumpBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.xxs) {
                Button(action: model.goBack) {
                    Label(L10n.goBack, systemImage: "chevron.left").labelStyle(.iconOnly)
                }
                .disabled(!model.canGoBack)
                .help(L10n.goBackHelp)
                .accessibilityIdentifier(AccessibilityID.Editor.back)
                Button(action: model.goForward) {
                    Label(L10n.goForward, systemImage: "chevron.right").labelStyle(.iconOnly)
                }
                .disabled(!model.canGoForward)
                .help(L10n.goForwardHelp)
                .accessibilityIdentifier(AccessibilityID.Editor.forward)
            }
            .buttonStyle(.borderless)

            Divider().frame(height: Theme.Layout.jumpBarDividerHeight)

            path
            Spacer(minLength: 0)
        }
        .font(Theme.Typography.footer)
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Editor.jumpBar)
    }

    @ViewBuilder
    private var path: some View {
        let descriptor = EngineCatalog.descriptor(for: session.engine)
        let activeObject = model.activeTab.flatMap(model.object(for:))
        JumpBarSegment(
            title: Text(verbatim: session.name), systemImage: descriptor.systemImage,
            showsSeparator: model.activeTab != nil, identifier: AccessibilityID.Editor.segment(0)
        )
        if let activeObject {
            JumpBarSegment(
                title: Text(verbatim: activeObject.schema), systemImage: "folder",
                choices: model.schemas.map { schema in
                    .init(id: schema, title: schema, systemImage: "folder") {
                        if let first = model.objects(inSchema: schema).first { model.open(first) }
                    }
                },
                identifier: AccessibilityID.Editor.segment(1)
            )
            JumpBarSegment(
                title: Text(verbatim: activeObject.name), systemImage: activeObject.kind.systemImage,
                choices: model.objects(inSchema: activeObject.schema).map { object in
                    .init(id: object.id, title: object.name, systemImage: object.kind.systemImage) { model.open(object) }
                },
                showsSeparator: false, identifier: AccessibilityID.Editor.segment(2)
            )
        } else if case .query(let key) = model.activeTab {
            JumpBarSegment(title: Text(L10n.queryResults), systemImage: "terminal", identifier: AccessibilityID.Editor.segment(1))
            JumpBarSegment(title: Text(verbatim: key), systemImage: "text.alignleft", showsSeparator: false, identifier: AccessibilityID.Editor.segment(2))
        }
    }
}

#Preview {
    let model = WorkspaceViewModel(client: StubDatabaseClient())
    EditorHeaderView(model: model, session: ConnectionSession(id: UUID(), name: "Local Postgres", engine: .postgreSQL, client: StubDatabaseClient()))
        .task {
            await model.load()
            if let first = model.objects.first { model.open(first) }
            model.showQuery("SELECT * FROM customers")
        }
        .frame(width: 800)
}
