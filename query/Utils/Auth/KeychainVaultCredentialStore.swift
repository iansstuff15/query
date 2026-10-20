import Foundation
import os

/// Every secret the app keeps (the connection-store key and saved passwords) in one Keychain
/// item, as a JSON object of account → secret, read once per launch and cached.
///
/// macOS asks for the login password per Keychain item whenever the app's code signature
/// changes (every build, while builds are signed to run locally), so one item means at most one
/// prompt per launch instead of one per secret.
///
/// If the Keychain refuses the read (the prompt was denied or cancelled), the store reports no
/// secrets and refuses writes for the rest of the launch, so it never replaces secrets it
/// couldn't read, such as the key that decrypts saved connections.
nonisolated final class KeychainVaultCredentialStore: SecretStore, @unchecked Sendable {
    static let vaultAccount = "vault"

    private enum State {
        case unloaded
        case loaded([String: String])
        case unavailable
    }

    private let items: any KeychainItemStoring
    private let lock = NSLock()
    private var state = State.unloaded

    init(items: any KeychainItemStoring) {
        self.items = items
    }

    convenience init(service: String) {
        self.init(items: KeychainCredentialStore(service: service))
    }

    func password(for account: String) -> String? {
        lock.withLock {
            guard case .loaded(let secrets) = loadIfNeeded() else { return nil }
            return secrets[account]
        }
    }

    func setPassword(_ password: String, for account: String) throws {
        try lock.withLock {
            guard case .loaded(var secrets) = loadIfNeeded() else { throw CredentialStoreError.unavailable }
            let value = password.isEmpty ? nil : password
            guard secrets[account] != value else { return }
            secrets[account] = value
            try save(secrets)
            state = .loaded(secrets)
        }
    }

    func allSecrets() throws -> [String: String] {
        try lock.withLock {
            guard case .loaded(let secrets) = loadIfNeeded() else { throw CredentialStoreError.unavailable }
            return secrets
        }
    }

    func replaceAll(with secrets: [String: String]) throws {
        try lock.withLock {
            guard case .loaded = loadIfNeeded() else { throw CredentialStoreError.unavailable }
            let kept = secrets.filter { !$0.value.isEmpty }
            try save(kept)
            state = .loaded(kept)
        }
    }

    // MARK: - Loading (call with the lock held)

    private func loadIfNeeded() -> State {
        if case .unloaded = state { state = load() }
        return state
    }

    private func load() -> State {
        do {
            if let json = try items.read(Self.vaultAccount) {
                guard let secrets = try? JSONDecoder().decode([String: String].self, from: Data(json.utf8)) else {
                    AppLog.keychain.error("The Keychain vault item is unreadable")
                    return .unavailable
                }
                return .loaded(secrets)
            }
            return .loaded(try migrateSeparateItems())
        } catch {
            AppLog.keychain.error("Keychain access refused: \(String(describing: error), privacy: .private)")
            return .unavailable
        }
    }

    /// Folds items written one per secret by earlier builds into the vault, then removes them.
    /// Their reads may each prompt, once, on the first launch of this build.
    private func migrateSeparateItems() throws -> [String: String] {
        let accounts = try items.accounts().filter { $0 != Self.vaultAccount }
        guard !accounts.isEmpty else { return [:] }
        var secrets: [String: String] = [:]
        for account in accounts {
            secrets[account] = try items.read(account)
        }
        try save(secrets)
        for account in accounts {
            try? items.write("", for: account)
        }
        AppLog.keychain.info("Moved \(accounts.count) Keychain items into the vault")
        return secrets
    }

    private func save(_ secrets: [String: String]) throws {
        let data = try JSONEncoder().encode(secrets)
        try items.write(String(decoding: data, as: UTF8.self), for: Self.vaultAccount)
    }
}
