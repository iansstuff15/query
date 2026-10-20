import AppKit

/// The SQL editor's left margin: a ▶ beside the first line of each statement. Clicking one runs
/// that statement. Each ▶ is also an accessibility button, since it's drawn rather than a view.
final class SQLGutterView: NSRulerView {
    var statements: [SQLEditorStatement] = [] {
        didSet { if statements != oldValue { needsDisplay = true } }
    }
    var isRunEnabled = true {
        didSet { if isRunEnabled != oldValue { needsDisplay = true } }
    }
    var onRun: ((SQLEditorStatement) -> Void)?

    init(textView: NSTextView, scrollView: NSScrollView) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = SyntaxPalette.gutterWidth
        setAccessibilityIdentifier(AccessibilityID.SQLConsole.gutter)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var requiredThickness: CGFloat { ruleThickness }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        let image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(paletteColors: [isRunEnabled ? SyntaxPalette.runGlyph : .tertiaryLabelColor]))
        for (_, frame) in buttonFrames() where frame.intersects(rect) {
            image?.draw(in: frame)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard isRunEnabled, let hit = buttonFrames().first(where: { $0.1.insetBy(dx: -4, dy: -4).contains(point) }) else {
            super.mouseDown(with: event)
            return
        }
        onRun?(hit.0)
    }

    override func isAccessibilityElement() -> Bool { false }

    override func accessibilityChildren() -> [Any]? {
        buttonFrames().map { statement, frame in
            let element = RunElement(statement: statement, gutter: self)
            element.setAccessibilityFrameInParentSpace(frame)
            return element
        }
    }

    /// The ▶ for each statement whose first line has been laid out, in this view's coordinates.
    private func buttonFrames() -> [(SQLEditorStatement, NSRect)] {
        guard let textView = clientView as? NSTextView, let layoutManager = textView.layoutManager else { return [] }
        let length = (textView.string as NSString).length
        let origin = convert(NSPoint(x: 0, y: textView.textContainerOrigin.y), from: textView)
        let side = SyntaxPalette.gutterGlyphSize
        return statements.compactMap { statement in
            guard statement.range.location < length else { return nil }
            let glyph = layoutManager.glyphIndexForCharacter(at: statement.range.location)
            let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let frame = NSRect(x: (ruleThickness - side) / 2, y: origin.y + line.minY + (line.height - side) / 2, width: side, height: side)
            return (statement, frame)
        }
    }

    /// A ▶ for VoiceOver and other assistive technologies.
    private final class RunElement: NSAccessibilityElement {
        private let statement: SQLEditorStatement
        private weak var gutter: SQLGutterView?

        init(statement: SQLEditorStatement, gutter: SQLGutterView) {
            self.statement = statement
            self.gutter = gutter
            super.init()
            setAccessibilityParent(gutter)
            setAccessibilityRole(.button)
            setAccessibilityLabel(L10n.runStatementAccessibilityLabel(statement.sql))
            setAccessibilityEnabled(gutter.isRunEnabled)
        }

        override func accessibilityPerformPress() -> Bool {
            guard let gutter, gutter.isRunEnabled else { return false }
            gutter.onRun?(statement)
            return true
        }
    }
}
