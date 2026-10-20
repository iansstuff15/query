import Foundation
import Testing
@testable import query

@Suite("Vertica simple-query support")
struct VerticaProtocolTests {
    @Test func binderInlinesEscapedLiterals() throws {
        let sql = try SQLLiteralBinder.bind(SQLStatement(sql: #"SELECT "a?b" FROM t WHERE x = ? AND y = '?' AND z IN (?, ?)"#, bindings: ["it's", "1", "2"]))
        #expect(sql == #"SELECT "a?b" FROM t WHERE x = 'it''s' AND y = '?' AND z IN ('1', '2')"#)
    }

    @Test func binderSkipsCommentsAndRejectsCountMismatch() throws {
        #expect(try SQLLiteralBinder.bind(SQLStatement(sql: "SELECT 1 -- ?\nWHERE a = ?", bindings: ["x"])) == "SELECT 1 -- ?\nWHERE a = 'x'")
        #expect(throws: DatabaseError.queryFailed) { try SQLLiteralBinder.bind(SQLStatement(sql: "a = ?", bindings: [])) }
        #expect(throws: DatabaseError.queryFailed) { try SQLLiteralBinder.bind(SQLStatement(sql: "a = 1", bindings: ["x"])) }
    }

    @Test func injectionPayloadStaysInsideLiteral() throws {
        let sql = try SQLLiteralBinder.bind(SQLStatement(sql: "WHERE a = ?", bindings: ["'; DROP TABLE t; --\0"]))
        #expect(sql == "WHERE a = '''; DROP TABLE t; --'")
    }

    @Test func parsesDataRowWithNull() throws {
        var payload = Data([0, 2])
        payload += Data([0, 0, 0, 2]) + Data("hi".utf8)
        payload += Data([0xFF, 0xFF, 0xFF, 0xFF])
        #expect(try PGSimpleQueryConnection.dataRow(payload) == ["hi", nil])
        #expect(throws: DatabaseError.protocolViolation) { try PGSimpleQueryConnection.dataRow(Data([0, 1, 0, 0, 0, 9])) }
    }

    @Test func md5PasswordMatchesPostgresAlgorithm() {
        // Expected value computed independently: md5(md5("secret" + "user").hex + salt).
        #expect(PGSimpleQueryConnection.md5Password(user: "user", password: "secret", salt: Data([1, 2, 3, 4])) == "md5fccef98e4f1cf6cbe96b743fad4e8bd0")
    }

    @Test func errorMessageField() {
        var payload = Data("SERROR".utf8) + Data([0]) + Data("Mbad thing".utf8) + Data([0, 0])
        #expect(PGSimpleQueryConnection.errorMessage(payload) == "bad thing")
        payload = Data([0])
        #expect(PGSimpleQueryConnection.errorMessage(payload) == "unknown error")
    }
}
