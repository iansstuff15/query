import Foundation
@testable import query

/// Thread-safe in-memory `CredentialStore`; `failsOnWrite` simulates Keychain errors.
final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var passwords: [String: String]
    private let failsOnWrite: Bool

    init(passwords: [String: String] = [:], failsOnWrite: Bool = false) {
        self.passwords = passwords
        self.failsOnWrite = failsOnWrite
    }

    func password(for account: String) -> String? {
        lock.withLock { passwords[account] }
    }

    func setPassword(_ password: String, for account: String) throws {
        if failsOnWrite { throw CredentialStoreError.unexpectedStatus(-25_300) }
        lock.withLock { passwords[account] = password.isEmpty ? nil : password }
    }
}
