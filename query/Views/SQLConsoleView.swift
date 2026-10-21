import SwiftUI

/// The workspace's right panel, in three tabs. Editor: the SQL editor (type, or open a `.sql`
/// file), Run All, and how the last run went. History: this connection's past statements, each
/// with its own Run button. Row: the selected table row's values, editable, with Save. Each line
/// of the editor, and each statement ending in `;`, runs on its own from the ▶ beside it (or ⌘↩
/// at the cursor), and each distinct statement's result gets its own tab in the center panel.
struct SQLConsoleView: View {
    @Bindable var model: SQLConsoleViewModel
    /// Tables and views of this connection, for highlighting and completion.
    let objects: [DatabaseObject]
    @Binding var tab: SQLConsoleTab
    /// The tabs to offer (features can be turned off in the Info.plist).
    var tabs: [SQLConsoleTab] = SQLConsoleTab.allCases
    /// The selected table row, for the Row tab.
    let rowEditor: RowEditorViewModel?
    /// Opens the `.sql` file panel (owned by the workspace, so ⌘O works too).
    let onOpenFile: () -> Void
    @State private var isEditorFocused = false
    @Environment(\.featureFlags) private var flags

    var body: some View {
        Group {
            if model.isSupported {
                VStack(spacing: 0) {
                    // Always on top: drawn above the tab's content, which can't reach under it.
                    if tabs.count > 1 {
                        tabPicker
                            .frame(maxWidth: .infinity)
                            .solidBarBackground()
                            .overlay(alignment: .bottom) { Divider() }
                            .zIndex(1)
                    }
                    tabContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
            } else {
                FallbackStateView(
                    title: L10n.sqlUnsupportedTitle, systemImage: "terminal",
                    message: L10n.sqlUnsupportedDetail, identifier: AccessibilityID.SQLConsole.unsupported
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.SQLConsole.panel)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .editor:
            VStack(spacing: 0) {
                // The editor gets the space left over and never draws outside it.
                editor
                    .frame(maxHeight: .infinity)
                    .clipped()
                VStack(spacing: 0) {
                    Divider()
                    runBar
                    Divider()
                    summary
                }
                .solidBarBackground()
                .zIndex(1)
            }
        case .history:
            historyList
        case .row:
            if let rowEditor {
                RowEditorView(model: rowEditor)
                    .id(ObjectIdentifier(rowEditor))
            } else {
                FallbackStateView(
                    title: L10n.selectRowTitle, systemImage: "tablecells",
                    message: L10n.selectRowDetail, identifier: AccessibilityID.RowEditor.empty
                )
            }
        }
    }

    private var tabPicker: some View {
        PanelTabBar(tabs: tabs, selection: $tab, title: Self.title(for:), systemImage: Self.systemImage(for:), identifier: AccessibilityID.SQLConsole.tabs)
            .padding(Theme.Spacing.s)
    }

    private static func title(for tab: SQLConsoleTab) -> LocalizedStringKey {
        switch tab {
        case .editor: L10n.sqlEditorTab
        case .history: L10n.sqlHistoryTab
        case .row: L10n.rowTab
        }
    }

    private static func systemImage(for tab: SQLConsoleTab) -> String {
        switch tab {
        case .editor: "chevron.left.forwardslash.chevron.right"
        case .history: "clock.arrow.circlepath"
        case .row: "list.bullet.rectangle"
        }
    }

    @ViewBuilder
    private var historyList: some View {
        if model.history.isEmpty {
            FallbackStateView(
                title: L10n.sqlHistoryEmptyTitle, systemImage: "clock.arrow.circlepath",
                message: L10n.sqlHistoryEmptyDetail, identifier: AccessibilityID.SQLConsole.historyEmpty
            )
        } else {
            VStack(spacing: 0) {
                List {
                    ForEach(Array(model.history.enumerated()), id: \.element.id) { index, item in
                        SQLHistoryRow(
                            item: item, isRunDisabled: model.isRunning, identifier: AccessibilityID.SQLConsole.historyItem(index),
                            onRun: { Task { await model.run(item) } },
                            onEdit: {
                                model.edit(item)
                                tab = .editor
                            },
                            onDelete: { model.deleteHistory(item) }
                        )
                        .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .accessibilityIdentifier(AccessibilityID.SQLConsole.history)
                HStack {
                    Spacer()
                    Button(role: .destructive, action: model.clearHistory) {
                        Label(L10n.clearHistory, systemImage: "trash")
                    }
                    .buttonStyle(.glass)
                    .help(L10n.clearHistoryHint)
                    .accessibilityHint(L10n.clearHistoryHint)
                    .accessibilityIdentifier(AccessibilityID.SQLConsole.clearHistory)
                }
                .barStyle(divider: .top)
            }
        }
    }

    private var editor: some View {
        SQLEditor(
            text: $model.text, isFocused: $isEditorFocused, objects: objects, isRunEnabled: !model.isRunning,
            isAutocompleteEnabled: flags.sqlAutocomplete, isHighlightingEnabled: flags.sqlSyntaxHighlighting,
            onRun: { statements in Task { await model.run(statements.map(\.sql)) } },
            onImportFile: model.importSQL(from:)
        )
            .frame(minHeight: Theme.Layout.sqlEditorMinHeight, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                if model.text.isEmpty {
                    Text(L10n.sqlPlaceholder)
                        .font(Theme.Typography.sql)
                        .foregroundStyle(.tertiary)
                        .padding(Theme.Spacing.m)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHint(L10n.runStatementHint)
            .help(L10n.runStatementHint)
            // Scene-wide: the editor is AppKit, so SwiftUI's own focus tracking doesn't see it.
            .focusedSceneValue(\.isEditingSQL, isEditorFocused)
    }

    private var runBar: some View {
        HStack {
            Button(action: onOpenFile) {
                Label(L10n.openSQLFile, systemImage: "doc.text")
            }
            .buttonStyle(.glass)
            .help(L10n.openSQLFileHint)
            .accessibilityHint(L10n.openSQLFileHint)
            .accessibilityIdentifier(AccessibilityID.SQLConsole.openFile)
            Spacer()
            Button { Task { await model.runAll() } } label: {
                Label(L10n.runAll, systemImage: "play.fill")
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.return, modifiers: [.command, .shift])
            .disabled(!model.canRun)
            .help(L10n.runAllHint)
            .accessibilityHint(L10n.runAllHint)
            .accessibilityIdentifier(AccessibilityID.SQLConsole.runAll)
        }
        .padding(Theme.Spacing.s)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if model.isRunning {
                HStack(spacing: Theme.Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text(L10n.sqlRunning).foregroundStyle(.secondary)
                }
            }
            if model.didFailToImport {
                Label(L10n.sqlImportFailed, systemImage: "xmark.circle.fill")
                    .foregroundStyle(Theme.Palette.statusFailure)
                    .accessibilityIdentifier(AccessibilityID.SQLConsole.importError)
            }
            if let batch = model.lastBatch {
                ScrollView {
                    SQLBatchSummaryView(batch: batch, onSelect: model.focus)
                }
                .frame(maxHeight: Theme.Layout.sqlBatchMaxHeight)
            } else if !model.isRunning {
                Text(L10n.sqlIdleDetail).foregroundStyle(.secondary)
            }
        }
        .font(Theme.Typography.footer)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.SQLConsole.status)
    }
}

#Preview {
    @Previewable @State var tab = SQLConsoleTab.editor
    SQLConsoleView(
        model: SQLConsoleViewModel(client: StubDatabaseClient(), text: "SELECT * FROM customers;"), objects: SampleCatalog.objects,
        tab: $tab, rowEditor: nil, onOpenFile: {}
    )
        .frame(width: 420, height: 600)
}
