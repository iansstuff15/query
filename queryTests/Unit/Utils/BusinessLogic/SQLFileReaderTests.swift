import Foundation
import Testing
@testable import query

@Suite("SQLFileReader")
struct SQLFileReaderTests {
    private func file(_ data: Data, extension ext: String = "sql") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "query-\(UUID().uuidString).\(ext)")
        try data.write(to: url)
        return url
    }

    @Test func readsUTF8() throws {
        let url = try file(Data("SELECT 'café';\nSELECT 2".utf8))
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try SQLFileReader.read(url) == "SELECT 'café';\nSELECT 2")
    }

    @Test func fallsBackToLatin1() throws {
        let url = try file(Data([0x53, 0x45, 0x4C, 0x45, 0x43, 0x54, 0x20, 0x27, 0xE9, 0x27])) // SELECT 'é' in Latin-1
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try SQLFileReader.read(url) == "SELECT 'é'")
    }

    @Test func refusesLargeFiles() throws {
        let url = try file(Data(repeating: 0x41, count: 64))
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: SQLFileReader.ReadError.tooLarge) { try SQLFileReader.read(url, maxBytes: 32) }
    }

    @Test func acceptsSQLAndTextFilesForDrops() {
        #expect(SQLFileReader.accepts(URL(filePath: "/tmp/seed.SQL")))
        #expect(SQLFileReader.accepts(URL(filePath: "/tmp/notes.txt")))
        #expect(!SQLFileReader.accepts(URL(filePath: "/tmp/photo.png")))
    }
}
