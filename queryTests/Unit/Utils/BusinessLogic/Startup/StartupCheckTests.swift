import Foundation
import SwiftData
import Testing
@testable import query

@Suite("Startup checks")
struct StartupCheckTests {
    @Test func embeddedEnginesLoad() async throws {
        let sqlite = await SQLiteCheck().run()
        #expect(sqlite.isPassed)
        guard case .passed(let duckVersion?) = await DuckDBCheck().run() else {
            Issue.record("DuckDB check did not pass")
            return
        }
        #expect(duckVersion.hasPrefix("v1."))
    }

    @Test func nativeLibrariesInitialize() async {
        #expect(await TLSCheck().run().isPassed)
        #expect(await CassandraDriverCheck().run().isPassed)
    }

    @Test func everyEngineHasADriver() async {
        #expect(await DriverRegistryCheck(factory: DefaultDatabaseClientFactory()).run() == .passed(detail: "21"))
        #expect(!(await DriverRegistryCheck(factory: FailingFactory()).run().isPassed))
    }

    @Test func keychainAndEncryption() async {
        #expect(await KeychainCheck(credentials: InMemoryCredentialStore()).run().isPassed)
        #expect(!(await KeychainCheck(credentials: InMemoryCredentialStore(failsOnWrite: true)).run().isPassed))
        let cipher = KeychainConnectionCipher(credentials: InMemoryCredentialStore())
        #expect(await EncryptionCheck(cipher: cipher).run() == .passed(detail: "AES-256-GCM"))
        let broken = KeychainConnectionCipher(credentials: InMemoryCredentialStore(failsOnWrite: true))
        #expect(!(await EncryptionCheck(cipher: broken).run().isPassed))
    }

    @Test func connectionStoreCheck() async throws {
        let container = try ModelContainer(for: SavedConnection.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        #expect(await ConnectionStoreCheck(container: container).run() == .passed(detail: "0"))
        #expect(!(await ConnectionStoreCheck(container: nil).run().isPassed))
    }
}
