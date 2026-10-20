import Foundation
import Testing
@testable import query

@Suite("TDS messages")
struct TDSMessagesTests {
    @Test func preLoginOffsetsPointPastTheOptionTable() {
        let data = [UInt8](TDSMessages.preLogin(encryption: .notSupported))
        // 5 options × 5 bytes + terminator = 26-byte table; VERSION payload starts at 26.
        #expect(Array(data[0..<5]) == [0x00, 0x00, 26, 0x00, 6])
        #expect(data[25] == 0xFF)
        #expect(data[26 + 6] == 0x02) // ENCRYPT_NOT_SUP
    }

    @Test func passwordObfuscationMatchesSpec() {
        // 'a' = 0x61 0x00 → swap nibbles 0x16 0x00 → xor 0xA5 → 0xB3 0xA5
        #expect([UInt8](TDSMessages.obfuscate("a")) == [0xB3, 0xA5])
    }

    @Test func login7HeaderAndLength() throws {
        let data = TDSMessages.login7(username: "sa", password: "pw", database: "app", serverName: "db", packetSize: 4_096)
        var reader = TDSReader(data)
        #expect(try reader.uint32() == UInt32(data.count))
        #expect(try reader.uint32() == 0x7400_0004)
        #expect(data.count == 94 + 2 * ("query" + "sa" + "pw" + "query" + "db" + "query" + "app").utf16.count)
    }

    @Test func parsesColumnMetadataNBCRowAndErrors() throws {
        var writer = TDSWriter()
        writer.uint8(0x81)              // COLMETADATA
        writer.uint16LE(2)
        for name in ["a", "b"] {
            writer.uint32LE(0); writer.uint16LE(0)
            writer.uint8(0xE7); writer.uint16LE(8_000); writer.bytes(TDSMessages.collation)
            writer.bVarChar(name)
        }
        writer.uint8(0xD2)              // NBCROW: b is NULL
        writer.uint8(0b10)
        writer.uint16LE(4); writer.utf16("hi")
        writer.uint8(0xFD); writer.bytes(Data(count: 12))
        let outcome = try TDSTokenParser.parse(writer.data)
        #expect(outcome.rows == [["hi", nil]])
        #expect(outcome.errors.isEmpty)
    }

    @Test func rpcEncodesPLPParameters() {
        let data = [UInt8](TDSMessages.executeSQL("SELECT @p1", bindings: ["x"]))
        #expect(Array(data[22..<24]) == [0xFF, 0xFF])
        #expect(Array(data[24..<26]) == [10, 0])   // sp_executesql
    }
}
