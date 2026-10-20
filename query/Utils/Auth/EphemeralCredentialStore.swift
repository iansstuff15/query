import Foundation

/// In-memory secrets for tests and previews, so runs never touch the Keychain or the secrets file.
nonisolated final class EphemeralCredentialStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func password(for account: String) -> String? {
        lock.withLock { values[account] }
    }

    func setPassword(_ password: String, for account: String) throws {
        lock.withLock { values[account] = password.isEmpty ? nil : password }
    }

    func allSecrets() throws -> [String: String] {
        lock.withLock { values }
    }

    func replaceAll(with secrets: [String: String]) throws {
        lock.withLock { values = secrets.filter { !$0.value.isEmpty } }
    }
}
