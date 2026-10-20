import Testing
@testable import query

@MainActor
@Suite("StartupConfigurationViewModel")
struct StartupConfigurationViewModelTests {
    @Test func startsOnTheActiveStore() {
        let switcher = SwitchableCredentialStore(stores: [.sqlite: EphemeralCredentialStore(), .keychain: EphemeralCredentialStore()], active: .keychain)
        #expect(StartupConfigurationViewModel(switcher: switcher).selectedStore == .keychain)
    }

    @Test func applyingMovesToTheSelectedStore() async throws {
        let keychain = EphemeralCredentialStore()
        let switcher = SwitchableCredentialStore(stores: [.sqlite: EphemeralCredentialStore(), .keychain: keychain], active: .sqlite)
        try switcher.setPassword("pw", for: "a")
        let model = StartupConfigurationViewModel(switcher: switcher)
        model.selectedStore = .keychain
        #expect(await model.applyStore())
        #expect(switcher.kind == .keychain)
        #expect(keychain.password(for: "a") == "pw")
        #expect(!model.didFailToSwitch)
        #expect(!model.isApplying)
    }

    @Test func aFailedSwitchKeepsTheCurrentStoreSelected() async {
        let switcher = SwitchableCredentialStore(stores: [.sqlite: EphemeralCredentialStore(), .keychain: UnreadableSecretStore()], active: .sqlite)
        let model = StartupConfigurationViewModel(switcher: switcher)
        model.selectedStore = .keychain
        #expect(await model.applyStore() == false)
        #expect(model.didFailToSwitch)
        #expect(model.selectedStore == .sqlite)
        #expect(switcher.kind == .sqlite)
    }

    @Test func applyingTheSameStoreSucceedsWithoutMoving() async {
        let switcher = SwitchableCredentialStore(stores: [.sqlite: EphemeralCredentialStore(), .keychain: UnreadableSecretStore()], active: .sqlite)
        #expect(await StartupConfigurationViewModel(switcher: switcher).applyStore())
    }

    // MARK: - Steps

    @Test func walksDisplayStoreReady() async {
        let switcher = SwitchableCredentialStore(stores: [.sqlite: EphemeralCredentialStore(), .keychain: EphemeralCredentialStore()], active: .sqlite)
        let model = StartupConfigurationViewModel(switcher: switcher)
        #expect(model.step == .language)
        #expect(!model.canGoBack)
        #expect(await model.goNext() == false)
        #expect(model.step == .display)
        #expect(model.canGoBack)
        #expect(await model.goNext() == false)
        #expect(model.step == .store)
        model.goBack()
        #expect(model.step == .display)
        _ = await model.goNext()
        model.selectedStore = .keychain
        #expect(await model.goNext() == false)
        #expect(model.step == .ready)
        #expect(switcher.kind == .keychain)
        #expect(model.isLastStep)
        #expect(await model.goNext())
    }

    @Test func aFailedStoreSwitchStaysOnTheStoreStep() async {
        let switcher = SwitchableCredentialStore(stores: [.sqlite: EphemeralCredentialStore(), .keychain: UnreadableSecretStore()], active: .sqlite)
        let model = StartupConfigurationViewModel(switcher: switcher, steps: [.store, .ready])
        model.selectedStore = .keychain
        _ = await model.goNext()
        #expect(model.step == .store)
        #expect(model.didFailToSwitch)
    }

    @Test func stepsFollowTheFeatureFlags() {
        #expect(SetupStep.steps(for: .allEnabled) == [.language, .display, .store, .ready])
        let off = FeatureFlags(infoDictionary: ["ENABLE_THEMES": false, "ENABLE_LANGUAGE_SETTING": "NO"])
        #expect(SetupStep.steps(for: off) == [.store, .ready])
        let model = StartupConfigurationViewModel(switcher: SwitchableCredentialStore(
            stores: [.sqlite: EphemeralCredentialStore(), .keychain: EphemeralCredentialStore()], active: .sqlite
        ), steps: SetupStep.steps(for: off))
        #expect(model.step == .store)
        #expect(model.number(of: .ready) == 2)
    }

    @Test func theKeychainIsOfferedOnlyWhenEnabledOrInUse() {
        let stores: [SecretStoreKind: any SecretStore] = [.sqlite: EphemeralCredentialStore(), .keychain: EphemeralCredentialStore()]
        let onSQLite = StartupConfigurationViewModel(switcher: SwitchableCredentialStore(stores: stores, active: .sqlite), offersKeychain: false)
        #expect(onSQLite.storeKinds == [.sqlite])
        let onKeychain = StartupConfigurationViewModel(switcher: SwitchableCredentialStore(stores: stores, active: .keychain), offersKeychain: false)
        #expect(onKeychain.storeKinds == [.sqlite, .keychain])
        #expect(StartupConfigurationViewModel(switcher: SwitchableCredentialStore(stores: stores, active: .sqlite)).storeKinds == [.sqlite, .keychain])
    }
}
