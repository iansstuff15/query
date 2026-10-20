import Foundation
import os

/// The credential store the app uses: forwards to the active `SecretStoreKind`, and moves every
/// secret (including the key that decrypts saved connections) when the user switches stores, so
/// switching never loses saved passwords or makes saved connections unreadable.
nonisolated final class SwitchableCredentialStore: CredentialStore, SecretStoreSwitching, @unchecked Sendable {
    private let stores: [SecretStoreKind: any SecretStore]
    private let onSwitch: @Sendable (SecretStoreKind) -> Void
    private let lock = NSLock()
    private var active: SecretStoreKind

    /// - Parameter onSwitch: persists the choice after a successful switch.
    init(
        stores: [SecretStoreKind: any SecretStore], active: SecretStoreKind,
        onSwitch: @escaping @Sendable (SecretStoreKind) -> Void = { _ in }
    ) {
        precondition(SecretStoreKind.allCases.allSatisfy { stores[$0] != nil }, "every store kind needs a store")
        self.stores = stores
        self.active = active
        self.onSwitch = onSwitch
    }

    var kind: SecretStoreKind {
        lock.withLock { active }
    }

    func password(for account: String) -> String? {
        current.password(for: account)
    }

    func setPassword(_ password: String, for account: String) throws {
        try current.setPassword(password, for: account)
    }

    func switchTo(_ kind: SecretStoreKind) throws {
        let didSwitch = try lock.withLock {
            guard kind != active, let source = stores[active], let destination = stores[kind] else { return false }
            let secrets = try source.allSecrets()
            try destination.replaceAll(with: secrets)
            // Only clear the old store once the new one has everything.
            do {
                try source.replaceAll(with: [:])
            } catch {
                AppLog.keychain.error("Clearing the previous secret store failed: \(String(describing: error), privacy: .private)")
            }
            AppLog.keychain.info("Moved \(secrets.count) secrets from \(self.active.rawValue, privacy: .public) to \(kind.rawValue, privacy: .public)")
            active = kind
            return true
        }
        if didSwitch { onSwitch(kind) }
    }

    private var current: any SecretStore {
        lock.withLock { stores[active] ?? EphemeralCredentialStore() }
    }
}
