import Foundation
import Security
import os

/// Stores secrets as generic-password Keychain items that stay on this Mac: readable only
/// while unlocked, never synced to iCloud Keychain or migrated to another device.
///
/// One item per account. The app itself goes through `KeychainVaultCredentialStore`, which keeps
/// everything in a single item so macOS asks for Keychain access at most once.
nonisolated struct KeychainCredentialStore: CredentialStore, KeychainItemStoring {
    let service: String

    func password(for account: String) -> String? {
        try? read(account)
    }

    func read(_ account: String) throws -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            AppLog.keychain.error("Keychain read failed with status \(status)")
            throw CredentialStoreError.unexpectedStatus(status)
        }
        return String(data: data, encoding: .utf8)
    }

    func write(_ value: String, for account: String) throws {
        try setPassword(value, for: account)
    }

    func accounts() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let attributes = items as? [[String: Any]] else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
        return attributes.compactMap { $0[kSecAttrAccount as String] as? String }
    }

    func setPassword(_ password: String, for account: String) throws {
        let deleteStatus = SecItemDelete(baseQuery(account) as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw CredentialStoreError.unexpectedStatus(deleteStatus)
        }
        guard !password.isEmpty else { return }
        var attributes = baseQuery(account)
        attributes[kSecValueData as String] = Data(password.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        attributes[kSecAttrLabel as String] = "query — \(account)"
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
        ]
    }
}
