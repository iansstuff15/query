import Foundation
import Observation
import os

/// The startup configuration's steps (Language → Display → Store → Ready, minus any whose
/// feature is off) and the secret-store choice, also
/// used by Settings. (The theme is a plain `@AppStorage` preference and applies as soon as it's
/// picked.)
@MainActor
@Observable
final class StartupConfigurationViewModel {
    var selectedStore: SecretStoreKind
    /// The steps shown, in order.
    let steps: [SetupStep]
    private(set) var step: SetupStep
    private(set) var isApplying = false
    /// The last switch failed, so the previous store is still in use.
    private(set) var didFailToSwitch = false

    private let switcher: any SecretStoreSwitching
    private let offersKeychain: Bool

    init(switcher: any SecretStoreSwitching, steps: [SetupStep] = SetupStep.allCases, offersKeychain: Bool = true) {
        self.switcher = switcher
        self.offersKeychain = offersKeychain
        selectedStore = switcher.kind
        self.steps = steps.isEmpty ? [.store, .ready] : steps
        step = self.steps[0]
    }

    /// The step's position among those shown, from 1.
    func number(of step: SetupStep) -> Int {
        (steps.firstIndex(of: step) ?? 0) + 1
    }

    private var stepIndex: Int { steps.firstIndex(of: step) ?? 0 }

    var activeStore: SecretStoreKind { switcher.kind }

    /// The stores to offer. With the Keychain turned off it's still listed while it's in use,
    /// so secrets can be moved off it.
    var storeKinds: [SecretStoreKind] {
        offersKeychain || activeStore == .keychain ? SecretStoreKind.allCases : [.sqlite]
    }

    var canGoBack: Bool { stepIndex > 0 && !isApplying }
    var isLastStep: Bool { step == steps.last }

    func goBack() {
        guard canGoBack else { return }
        step = steps[stepIndex - 1]
    }

    /// Moves to the next step; leaving Store applies the store choice and stays put if that
    /// fails. Returns `true` when the last step is done, so the window can close.
    func goNext() async -> Bool {
        if step == .store, !(await applyStore()) { return false }
        guard stepIndex + 1 < steps.count else { return true }
        step = steps[stepIndex + 1]
        return false
    }

    /// Moves secrets to the selected store. Returns whether the selection is now in use; on
    /// failure the selection goes back to the store still in use.
    @discardableResult
    func applyStore() async -> Bool {
        let target = selectedStore
        guard target != switcher.kind else {
            didFailToSwitch = false
            return true
        }
        isApplying = true
        defer { isApplying = false }
        let switcher = switcher
        do {
            // The Keychain may show a password prompt, so stay off the main thread.
            try await Task.detached { try switcher.switchTo(target) }.value
            didFailToSwitch = false
            return true
        } catch {
            AppLog.keychain.error("Switching the secret store failed: \(String(describing: error), privacy: .private)")
            didFailToSwitch = true
            selectedStore = switcher.kind
            return false
        }
    }
}
