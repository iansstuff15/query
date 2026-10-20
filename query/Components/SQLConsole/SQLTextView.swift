import AppKit

/// The SQL console's text view: completion replaces the word being typed (including `_` and
/// `$`), a suggestion is only inserted when accepted (Return, Tab or a click, not while
/// browsing the list), focus changes are reported, and ⌘↩ runs the statement at the cursor (or
/// the statements in the selection).
final class SQLTextView: NSTextView {
    var onFocusChange: ((Bool) -> Void)?
    var onRunStatements: (([SQLEditorStatement]) -> Void)?
    /// A `.sql` file dropped on the editor.
    var onImportFile: ((URL) -> Void)?

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        guard let file = urls?.first(where: SQLFileReader.accepts) else { return super.performDragOperation(sender) }
        onImportFile?(file)
        return true
    }

    /// The statements ⌘↩ runs: those in the selection, or the one at the cursor.
    var statementsAtSelection: [SQLEditorStatement] {
        SQLStatementSplitter.statements(in: string, for: selectedRange())
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isReturn = event.keyCode == 36 || event.keyCode == 76 // Return, keypad Enter
        if isReturn, modifiers == .command, window?.firstResponder === self {
            let statements = statementsAtSelection
            if !statements.isEmpty { onRunStatements?(statements) }
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { onFocusChange?(true) }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onFocusChange?(false) }
        return resigned
    }

    override var rangeForUserCompletion: NSRange {
        SQLCompletion.context(in: string, at: selectedRange().location).range
    }

    override func insertCompletion(_ word: String, forPartialWordRange charRange: NSRange, movement: Int, isFinal flag: Bool) {
        // Browsing the list (not final) or cancelling (Esc) leaves the typed text alone.
        guard flag, movement != NSTextMovement.cancel.rawValue else { return }
        super.insertCompletion(word, forPartialWordRange: charRange, movement: movement, isFinal: flag)
    }
}
