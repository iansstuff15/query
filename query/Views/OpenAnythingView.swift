import SwiftUI

/// ⌘P palette: type to rank tables and views locally, arrows to move, Return to open.
struct OpenAnythingView: View {
    @State private var model: OpenAnythingViewModel
    @FocusState private var isSearchFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let onSelect: (DatabaseObject) -> Void

    init(objects: [DatabaseObject], matcher: TextMatcher, onSelect: @escaping (DatabaseObject) -> Void) {
        _model = State(initialValue: OpenAnythingViewModel(objects: objects, matcher: matcher))
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(
                text: $model.query,
                prompt: L10n.openAnythingPrompt,
                hint: L10n.openAnythingHint,
                identifier: AccessibilityID.OpenAnything.searchField,
                size: .large,
                isFocused: $isSearchFocused
            )
            .onSubmit(commit)
            .onKeyPress(.downArrow) { move(by: 1) }
            .onKeyPress(.upArrow) { move(by: -1) }
            .onKeyPress(.escape) {
                dismiss()
                return .handled
            }
            Divider()
            results
        }
        .frame(width: Theme.Layout.paletteWidth, height: Theme.Layout.paletteHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.OpenAnything.panel)
        .onAppear { isSearchFocused = true }
    }

    @ViewBuilder
    private var results: some View {
        if model.results.isEmpty {
            FallbackStateView(
                title: L10n.noMatches, systemImage: "magnifyingglass",
                message: L10n.noMatchesDetail, identifier: AccessibilityID.OpenAnything.empty
            )
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.xxs) {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, match in
                            OpenAnythingRow(
                                match: match,
                                isHighlighted: index == model.highlightedIndex,
                                identifier: AccessibilityID.OpenAnything.result(index),
                                onSelect: { select(match.object) }
                            )
                            .id(match.id)
                        }
                    }
                    .padding(Theme.Spacing.s)
                }
                .onChange(of: model.highlightedIndex) { _, index in
                    guard model.results.indices.contains(index) else { return }
                    withAnimation(Motion.animation(Motion.highlight, reduceMotion: reduceMotion)) {
                        proxy.scrollTo(model.results[index].id)
                    }
                }
            }
        }
    }

    private func move(by delta: Int) -> KeyPress.Result {
        model.moveHighlight(by: delta)
        return .handled
    }

    private func commit() {
        guard let object = model.highlightedObject else { return }
        select(object)
    }

    private func select(_ object: DatabaseObject) {
        onSelect(object)
        dismiss()
    }
}

#Preview {
    OpenAnythingView(objects: SampleCatalog.objects, matcher: TextMatcher(strategy: .fuzzy), onSelect: { _ in })
}
