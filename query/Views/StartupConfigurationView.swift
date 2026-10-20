import SwiftUI

/// Shown after the splash screen on first launch (or every launch with
/// `ALWAYS_SHOW_STARTUP_CONFIG`): a fixed-size, step-by-step setup. Language picks the display
/// language, Display the color theme, Store where saved passwords live, and Ready sums up. Each
/// can be changed later in Settings; Language and Display are left out when their features are
/// off in the Info.plist.
struct StartupConfigurationView: View {
    @State private var model: StartupConfigurationViewModel
    @AppStorage(SettingsKey.theme) private var theme: AppTheme = .classic
    @AppStorage(SettingsKey.language) private var language: AppLanguage = .system
    @AppStorage(SettingsKey.setupCompleted) private var isCompleted = false
    @State private var didContinue = false
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(switcher: any SecretStoreSwitching, flags: FeatureFlags = .current) {
        _model = State(initialValue: StartupConfigurationViewModel(
            switcher: switcher, steps: SetupStep.steps(for: flags), offersKeychain: flags.keychainStore
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                stepContent
                    .padding(Theme.Spacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(model.step)
                    .transition(Motion.stepTransition(reduceMotion: reduceMotion))
            }
            .frame(maxHeight: .infinity)
            Divider()
            footer
        }
        .animation(Motion.animation(Motion.reveal, reduceMotion: reduceMotion), value: model.step)
        .frame(width: Theme.Layout.setupWidth, height: Theme.Layout.setupHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Setup.window)
        .onChange(of: language) { _, language in LanguagePreference().apply(language) }
        .onDisappear {
            // Closing the window skips the rest of the configuration; the defaults stay.
            guard !didContinue else { return }
            isCompleted = true
            openWindow(id: SceneID.main)
        }
    }

    // MARK: - Header: title and step indicator

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(L10n.setupTitle).font(.largeTitle.bold())
                Text(L10n.setupSubtitle).foregroundStyle(.secondary)
            }
            HStack(spacing: Theme.Spacing.s) {
                ForEach(model.steps) { step in
                    SetupStepIndicator(
                        title: L10n.setupStepTitle(step), systemImage: step.systemImage, number: model.number(of: step),
                        state: step == model.step ? .current : (step.rawValue < model.step.rawValue ? .done : .upcoming),
                        identifier: AccessibilityID.Setup.step(step.rawValue)
                    )
                    if step != model.steps.last {
                        Rectangle()
                            .fill(step.rawValue < model.step.rawValue ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator))
                            .frame(height: Theme.Layout.borderWidth)
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.l)
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .language:
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                stepHeading(L10n.languageSection, detail: L10n.languageSectionDetail)
                LanguagePicker(selection: $language)
            }
        case .display:
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                stepHeading(L10n.displaySection, detail: L10n.displaySectionDetail)
                ThemePicker(selection: $theme)
            }
        case .store:
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                stepHeading(L10n.storeSection, detail: L10n.storeSectionDetail)
                SecretStorePicker(
                    selection: $model.selectedStore, kinds: model.storeKinds, isApplying: model.isApplying, didFailToSwitch: model.didFailToSwitch
                )
            }
        case .ready:
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                stepHeading(L10n.setupReadyTitle, detail: L10n.setupReadyDetail)
                if model.steps.contains(.language) {
                    LabeledContent(L10n.languageSection) {
                        if let name = language.nativeName { Text(verbatim: name) } else { Text(L10n.languageSystem) }
                    }
                }
                if model.steps.contains(.display) {
                    LabeledContent(L10n.displaySection) {
                        Text(L10n.themeName(theme))
                    }
                }
                LabeledContent(L10n.storeSection) {
                    Label(L10n.storeName(model.activeStore), systemImage: model.activeStore.systemImage)
                }
            }
            .accessibilityIdentifier(AccessibilityID.Setup.summary)
        }
    }

    private func stepHeading(_ title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(title).font(.title2.bold())
            Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Footer: Back / Next

    private var footer: some View {
        HStack {
            Button(action: model.goBack) {
                Label(L10n.setupBack, systemImage: "chevron.left")
            }
            .buttonStyle(.glass)
            .opacity(model.step == model.steps.first ? 0 : 1)
            .disabled(!model.canGoBack)
            .accessibilityHidden(model.step == model.steps.first)
            .accessibilityIdentifier(AccessibilityID.Setup.back)
            Spacer()
            Button { Task { await next() } } label: {
                if model.isLastStep {
                    Label(L10n.setupContinue, systemImage: "arrow.right")
                } else {
                    Label(L10n.setupNext, systemImage: "chevron.right")
                }
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(model.isApplying)
            .help(model.isLastStep ? L10n.setupContinueHint : L10n.setupNextHint)
            .accessibilityHint(model.isLastStep ? L10n.setupContinueHint : L10n.setupNextHint)
            .accessibilityIdentifier(AccessibilityID.Setup.continueButton)
        }
        .padding(Theme.Spacing.l)
    }

    private func next() async {
        guard await model.goNext() else { return }
        didContinue = true
        isCompleted = true
        openWindow(id: SceneID.main)
        dismissWindow(id: SceneID.setup)
    }
}

#Preview {
    StartupConfigurationView(switcher: SwitchableCredentialStore(
        stores: [.sqlite: EphemeralCredentialStore(), .keychain: EphemeralCredentialStore()], active: .sqlite
    ))
}
