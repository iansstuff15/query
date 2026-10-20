import SwiftUI

/// Launch screen in the style of creative-suite splashes: brand artwork, version, and a live
/// list of the dependency checks, then hands off to the main window.
struct SplashView: View {
    @State private var model: SplashViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Which window opens after the checks: the startup configuration on first launch, else the main window.
    private let nextScene: () -> String

    init(checks: [any StartupCheck], minimumDuration: Duration, nextScene: @escaping () -> String = { SceneID.main }) {
        _model = State(initialValue: SplashViewModel(checks: checks, minimumDuration: minimumDuration))
        self.nextScene = nextScene
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            artwork
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                brand
                Spacer(minLength: 0)
                status
            }
            .padding(Theme.Spacing.xl)
        }
        .frame(width: Theme.Layout.splashWidth, height: Theme.Layout.splashHeight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.splash, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Splash.window)
        .task {
            await model.run()
            openWindow(id: nextScene())
            dismissWindow(id: SceneID.splash)
        }
    }

    /// Decorative gradient with the app glyph; content-layer, so no glass here.
    private var artwork: some View {
        LinearGradient(colors: [Theme.Palette.splashTop, Theme.Palette.splashBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "cylinder.split.1x2.fill")
                    .font(Theme.Typography.splashArtwork)
                    .foregroundStyle(.white.opacity(0.18))
                    .rotationEffect(.degrees(-12))
                    .offset(x: Theme.Spacing.xl, y: -Theme.Spacing.l)
                    .accessibilityHidden(true)
            }
            .accessibilityHidden(true)
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(L10n.appName)
                .font(Theme.Typography.splashTitle)
                .foregroundStyle(.white)
            Text(L10n.splashTagline)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.85))
            Text(L10n.version(Bundle.main.shortVersion, Bundle.main.buildNumber))
                .font(Theme.Typography.footer)
                .foregroundStyle(.white.opacity(0.7))
                .accessibilityIdentifier(AccessibilityID.Splash.version)
        }
    }

    /// The functional layer floats on the artwork as Liquid Glass.
    private var status: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ProgressView(value: model.progress)
                .animation(Motion.animation(Motion.reveal, reduceMotion: reduceMotion), value: model.progress)
                .accessibilityLabel(L10n.loading)
                .accessibilityValue(Text(model.progress, format: .percent.precision(.fractionLength(0))))
                .accessibilityIdentifier(AccessibilityID.Splash.progress)
            Text(model.current.map { L10n.running(for: $0) } ?? L10n.splashStarting)
                .font(Theme.Typography.footer)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(AccessibilityID.Splash.currentStep)
            Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.l, verticalSpacing: Theme.Spacing.xxs) {
                ForEach(rows, id: \.self) { pair in
                    GridRow {
                        ForEach(pair) { id in
                            StartupCheckRow(id: id, state: model.states[id] ?? .pending)
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.m)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.large))
    }

    /// Checks laid out two per row.
    private var rows: [[StartupCheckID]] {
        stride(from: 0, to: model.order.count, by: 2).map { Array(model.order[$0..<min($0 + 2, model.order.count)]) }
    }
}

#Preview {
    SplashView(checks: [SQLiteCheck(), TLSCheck(), NetworkCheck()], minimumDuration: .seconds(30))
}
