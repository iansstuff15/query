import AppKit
import SwiftUI

/// The SQL console's editor: reserved words and table names in their own colors (strings,
/// numbers and comments too), a completion list of reserved words and table names that opens
/// as you type, and a ▶ in the margin beside each statement (each line, and each `;`) that runs
/// it; ⌘↩ runs the one at the cursor. Wraps `NSTextView`, because SwiftUI's `TextEditor` has no
/// completion list or margin.
struct SQLEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    /// Tables, views and other objects to highlight and suggest.
    let objects: [DatabaseObject]
    /// False while a run is in progress: the ▶s dim and ⌘↩ does nothing.
    let isRunEnabled: Bool
    /// `ENABLE_SQL_AUTOCOMPLETE`
    var isAutocompleteEnabled = true
    /// `ENABLE_SQL_SYNTAX_HIGHLIGHTING`
    var isHighlightingEnabled = true
    let onRun: ([SQLEditorStatement]) -> Void
    /// A `.sql` file dropped on the editor.
    var onImportFile: (URL) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let size = scrollView.contentSize
        let textView = SQLTextView(frame: NSRect(origin: .zero, size: size))
        textView.minSize = NSSize(width: 0, height: size.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: size.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: Theme.Spacing.xs, height: Theme.Spacing.s)
        scrollView.documentView = textView

        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.font = SyntaxPalette.font
        textView.typingAttributes = [.font: SyntaxPalette.font, .foregroundColor: SyntaxPalette.text]
        textView.setAccessibilityLabel(L10n.sqlEditorAccessibilityLabel)
        textView.setAccessibilityIdentifier(AccessibilityID.SQLConsole.editor)

        textView.delegate = context.coordinator
        textView.onFocusChange = { [weak coordinator = context.coordinator] focused in
            coordinator?.parent.isFocused = focused
        }
        textView.onRunStatements = { [weak coordinator = context.coordinator] statements in
            coordinator?.run(statements)
        }
        textView.onImportFile = { [weak coordinator = context.coordinator] url in
            coordinator?.parent.onImportFile(url)
        }

        let gutter = SQLGutterView(textView: textView, scrollView: scrollView)
        gutter.onRun = { [weak coordinator = context.coordinator] statement in
            coordinator?.run([statement])
        }
        scrollView.verticalRulerView = gutter
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        textView.string = text
        context.coordinator.textView = textView
        context.coordinator.gutter = gutter
        context.coordinator.highlight()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        let objectsChanged = coordinator.parent.objects != objects
        coordinator.parent = self
        coordinator.gutter?.isRunEnabled = isRunEnabled
        guard let textView = coordinator.textView else { return }
        if textView.string != text {
            // Set from outside (history, restored state): keep the cursor where it can be.
            let selection = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
            coordinator.highlight()
        } else if objectsChanged {
            coordinator.highlight()
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SQLEditor
        weak var textView: SQLTextView?
        weak var gutter: SQLGutterView?
        /// Whether the last edit typed something, so deleting doesn't reopen the list.
        private var lastEditInserted = false

        init(parent: SQLEditor) {
            self.parent = parent
        }

        private var tableNames: Set<String> {
            Set(parent.objects.map { $0.name.lowercased() })
        }

        func highlight() {
            guard let textView, let storage = textView.textStorage else { return }
            SQLSyntaxHighlighter.highlight(storage, tables: parent.isHighlightingEnabled ? tableNames : [], colorsTokens: parent.isHighlightingEnabled)
            gutter?.statements = SQLStatementSplitter.statements(in: textView.string)
        }

        func run(_ statements: [SQLEditorStatement]) {
            guard parent.isRunEnabled, !statements.isEmpty else { return }
            parent.onRun(statements)
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String?) -> Bool {
            lastEditInserted = !(replacementString ?? "").isEmpty
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
            highlight()
            if lastEditInserted, shouldSuggest(in: textView) {
                textView.complete(nil)
            }
        }

        func textView(
            _ textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange,
            indexOfSelectedItem index: UnsafeMutablePointer<Int>?
        ) -> [String] {
            index?.pointee = 0
            guard parent.isAutocompleteEnabled else { return [] }
            let context = SQLCompletion.context(in: textView.string, at: textView.selectedRange().location)
            return SQLCompletion.suggestions(for: context, objects: parent.objects)
        }

        /// After typing a word character or a `.`, outside strings and comments, when there's
        /// something to suggest.
        private func shouldSuggest(in textView: NSTextView) -> Bool {
            guard parent.isAutocompleteEnabled else { return false }
            let location = textView.selectedRange().location
            guard textView.selectedRange().length == 0, location > 0 else { return false }
            let units = Array(textView.string.utf16)
            let last = units[location - 1]
            guard SQLTokenizer.isWordPart(last) || last == 0x2E else { return false }
            let insideLiteral = SQLTokenizer.tokens(in: textView.string, tables: []).contains { token in
                (token.kind == .string || token.kind == .comment) && NSLocationInRange(location - 1, token.range)
            }
            guard !insideLiteral else { return false }
            let context = SQLCompletion.context(in: textView.string, at: location)
            return !SQLCompletion.suggestions(for: context, objects: parent.objects).isEmpty
        }
    }
}

#Preview {
    @Previewable @State var text = "SELECT id, full_name FROM customers WHERE country = 'US' -- note\nSELECT * FROM orders; SELECT 1;"
    @Previewable @State var focused = false
    SQLEditor(text: $text, isFocused: $focused, objects: SampleCatalog.objects, isRunEnabled: true, onRun: { _ in })
        .frame(width: 420, height: 240)
}
