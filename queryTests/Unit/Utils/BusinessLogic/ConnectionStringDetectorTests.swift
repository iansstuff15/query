import Testing
@testable import query

@Suite("ConnectionStringDetector")
struct ConnectionStringDetectorTests {
    @Test(arguments: [
        ("postgresql://query_reader:ReaderPass1@localhost:55432/app?sslmode=disable", DatabaseEngine.postgreSQL),
        ("jdbc:postgresql://localhost/app?user=me", .postgreSQL),
        ("mysql://query_reader:ReaderPass1@localhost:33306/app", .mySQL),
        ("Server=localhost,14330;Database=app;User Id=query_reader;Password=ReaderPass1;Encrypt=False", .sqlServer),
        ("query_reader/ReaderPass1@localhost:15210/FREEPDB1", .oracle),
        ("localhost:1521/FREEPDB1", .oracle),
        ("mongodb://query_reader:ReaderPass1@localhost:27018/app?authSource=app", .mongoDB),
        ("http://query_reader:ReaderPass1@localhost:19200", .elasticsearch),
        ("sqlite:///Users/me/app.sqlite", .sqlite),
        ("/Users/me/Library/app.duckdb", .duckDB),
    ])
    func recognizesConnectionStrings(text: String, engine: DatabaseEngine) {
        #expect(ConnectionStringDetector.detect(text, for: engine) == text)
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(ConnectionStringDetector.detect("  mysql://root@db:3306/app\n", for: .mySQL) == "mysql://root@db:3306/app")
    }

    @Test(arguments: [
        ("mysql://root@db:3306/app", DatabaseEngine.postgreSQL), // another engine's scheme
        ("hello world", .oracle), // the parser alone would take this as a host
        ("FREEPDB1", .oracle),
        ("/Users/me/notes.txt", .sqlite), // not a database file
        ("https://www.example.com/docs/elasticsearch", .elasticsearch), // a web link, no port
        ("postgres://a@b\npostgres://c@d", .postgreSQL), // multi-line selection
        ("SELECT * FROM customers;", .sqlServer),
        ("", .postgreSQL),
    ])
    func ignoresOtherText(text: String, engine: DatabaseEngine) {
        #expect(ConnectionStringDetector.detect(text, for: engine) == nil)
    }
}
