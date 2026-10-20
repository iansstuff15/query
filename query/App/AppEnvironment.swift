import Foundation
import SwiftData
import os

/// Dependency wiring: real drivers normally, stub data under `-UITesting` / `MOCK_DB`.
enum AppEnvironment {
    static func makeClientFactory(options: LaunchOptions = .current) -> any DatabaseClientFactory {
        if let scenario = options.stubScenario {
            return StubDatabaseClientFactory(scenario: scenario, delay: options.stubDelay)
        }
        return DefaultDatabaseClientFactory()
    }

    /// Secrets in the store the user picked: a SQLite file by default, or the Keychain (all in
    /// one item, so one access prompt at most). In memory under tests.
    static func makeCredentialStore(
        options: LaunchOptions = .current, defaults: UserDefaults = .standard
    ) -> SwitchableCredentialStore {
        if options.isIsolated {
            return SwitchableCredentialStore(stores: [.sqlite: EphemeralCredentialStore(), .keychain: EphemeralCredentialStore()], active: .sqlite)
        }
        let keychain = KeychainCredentialStore(service: AppConfig.keychainService)
        let saved = defaults.string(forKey: SettingsKey.secretStore).flatMap(SecretStoreKind.init(rawValue:))
        // Builds before this setting kept secrets in the Keychain: stay there until the user moves
        // them, or the key for saved connections would be lost. Listing items never prompts.
        let active = saved ?? (((try? keychain.accounts()) ?? []).isEmpty ? .sqlite : .keychain)
        defaults.set(active.rawValue, forKey: SettingsKey.secretStore)
        return SwitchableCredentialStore(
            stores: [
                .sqlite: SQLiteCredentialStore(fileURL: SQLiteCredentialStore.defaultFileURL),
                .keychain: KeychainVaultCredentialStore(items: keychain),
            ],
            active: active,
            onSwitch: { UserDefaults.standard.set($0.rawValue, forKey: SettingsKey.secretStore) }
        )
    }

    /// Whether the splash hands off to the startup configuration: on first launch, or on every
    /// launch when `ALWAYS_SHOW_STARTUP_CONFIG` is set. Never under tests.
    static func needsSetup(
        options: LaunchOptions = .current, flags: FeatureFlags = .current, defaults: UserDefaults = .standard
    ) -> Bool {
        !options.isIsolated && (flags.alwaysShowStartupConfig || !defaults.bool(forKey: SettingsKey.setupCompleted))
    }

    /// The system clipboard, or an empty one under tests (so runs don't depend on what was last
    /// copied) or with `ENABLE_CLIPBOARD_CONNECTION_STRINGS` off.
    static func makeClipboard(options: LaunchOptions = .current, flags: FeatureFlags = .current) -> any ClipboardReading {
        options.isIsolated || !flags.clipboardConnectionStrings ? EmptyClipboard() : SystemClipboard()
    }

    /// AES-GCM vault for saved connection details, keyed from the selected secret store.
    static func makeCipher(credentials: any CredentialStore) -> any ConnectionCipher {
        KeychainConnectionCipher(credentials: credentials)
    }

    /// On-disk SwiftData store, or in-memory under tests or if the store cannot open.
    static func makeModelContainer(options: LaunchOptions = .current) -> ModelContainer? {
        let inMemory = options.isIsolated
        do {
            return try ModelContainer(
                for: SavedConnection.self, SQLHistoryEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
            )
        } catch {
            AppLog.database.error("Opening the connection store failed: \(String(describing: error), privacy: .private)")
            return try? ModelContainer(
                for: SavedConnection.self, SQLHistoryEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }

    /// Checks run behind the splash screen, in display order.
    static func startupChecks(
        container: ModelContainer?, credentials: any CredentialStore, cipher: any ConnectionCipher, factory: any DatabaseClientFactory
    ) -> [any StartupCheck] {
        [
            ConnectionStoreCheck(container: container),
            KeychainCheck(credentials: credentials),
            EncryptionCheck(cipher: cipher),
            SQLiteCheck(),
            DuckDBCheck(),
            TLSCheck(),
            CassandraDriverCheck(),
            DriverRegistryCheck(factory: DefaultDatabaseClientFactory()),
            NetworkCheck(),
        ]
    }
}
