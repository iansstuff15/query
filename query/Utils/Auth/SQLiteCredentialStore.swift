import Foundation
import SQLite3
import os

/// Secrets in a SQLite file inside the app's sandbox container (`account → value`), readable
/// only by this app and your user account. Unlike the Keychain it never prompts, but the file
/// isn't encrypted by the system, and it's included in backups of the container.
nonisolated final class SQLiteCredentialStore: SecretStore, @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
    private var handle: OpaquePointer?

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// `secrets.sqlite` in the container's Application Support folder.
    static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: AppConfig.logSubsystem).appending(path: "secrets.sqlite")
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    func password(for account: String) -> String? {
        lock.withLock {
            do {
                return try query("SELECT value FROM secrets WHERE account = ?1", [account]).first?.0
            } catch {
                AppLog.keychain.error("Reading a secret from SQLite failed: \(String(describing: error), privacy: .private)")
                return nil
            }
        }
    }

    func setPassword(_ password: String, for account: String) throws {
        try lock.withLock {
            if password.isEmpty {
                try run("DELETE FROM secrets WHERE account = ?1", [account])
            } else {
                try run("INSERT INTO secrets (account, value) VALUES (?1, ?2) ON CONFLICT(account) DO UPDATE SET value = excluded.value", [account, password])
            }
        }
    }

    func allSecrets() throws -> [String: String] {
        try lock.withLock {
            Dictionary(try query("SELECT account, value FROM secrets", []), uniquingKeysWith: { _, last in last })
        }
    }

    func replaceAll(with secrets: [String: String]) throws {
        try lock.withLock {
            try run("BEGIN IMMEDIATE", [])
            do {
                try run("DELETE FROM secrets", [])
                for (account, value) in secrets where !value.isEmpty {
                    try run("INSERT INTO secrets (account, value) VALUES (?1, ?2)", [account, value])
                }
                try run("COMMIT", [])
            } catch {
                try? run("ROLLBACK", [])
                throw error
            }
        }
    }

    // MARK: - SQLite (call with the lock held)

    private func database() throws -> OpaquePointer {
        if let handle { return handle }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var opened: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(fileURL.path, &opened, flags, nil) == SQLITE_OK, let opened else {
            sqlite3_close_v2(opened)
            throw CredentialStoreError.unavailable
        }
        handle = opened
        // Owner read/write only.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        try run("CREATE TABLE IF NOT EXISTS secrets (account TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)", [])
        return opened
    }

    private func run(_ sql: String, _ bindings: [String]) throws {
        _ = try query(sql, bindings)
    }

    /// Runs `sql`, returning rows of (column 0, column 1) as text.
    private func query(_ sql: String, _ bindings: [String]) throws -> [(String, String)] {
        let database = try database()
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            AppLog.keychain.error("SQLite secret store: \(String(cString: sqlite3_errmsg(database)), privacy: .private)")
            throw CredentialStoreError.unavailable
        }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (offset, value) in bindings.enumerated() {
            sqlite3_bind_text(statement, Int32(offset + 1), value, -1, transient)
        }
        var rows: [(String, String)] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                let first = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
                let second = sqlite3_column_count(statement) > 1 ? sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? "" : ""
                rows.append((first, second))
            case SQLITE_DONE:
                return rows
            default:
                AppLog.keychain.error("SQLite secret store: \(String(cString: sqlite3_errmsg(database)), privacy: .private)")
                throw CredentialStoreError.unavailable
            }
        }
    }
}
