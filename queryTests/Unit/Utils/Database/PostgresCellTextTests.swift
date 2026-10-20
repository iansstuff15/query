import Foundation
import NIOCore
import PostgresNIO
import Testing
@testable import query

@Suite("PostgresCellText")
struct PostgresCellTextTests {
    private func cell(_ value: some PostgresEncodable, as type: PostgresDataType) throws -> PostgresCell {
        var buffer = ByteBuffer()
        try value.encode(into: &buffer, context: .default)
        return PostgresCell(bytes: buffer, dataType: type, format: .binary, columnName: "c", columnIndex: 0)
    }

    @Test func nullIsNil() {
        #expect(PostgresCellText.text(PostgresCell(bytes: nil, dataType: .int4, format: .binary, columnName: "c", columnIndex: 0)) == nil)
    }

    @Test func numbersAndBooleans() throws {
        #expect(PostgresCellText.text(try cell(Int32(42), as: .int4)) == "42")
        #expect(PostgresCellText.text(try cell(Int64(-7), as: .int8)) == "-7")
        #expect(PostgresCellText.text(try cell(1.5, as: .float8)) == "1.5")
        #expect(PostgresCellText.text(try cell(true, as: .bool)) == "true")
        #expect(PostgresCellText.text(try cell(try #require(Decimal(string: "329.99")), as: .numeric)) == "329.99")
    }

    @Test func textAndUUID() throws {
        #expect(PostgresCellText.text(try cell("Ada Lovelace", as: .text)) == "Ada Lovelace")
        let id = try #require(UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF"))
        #expect(PostgresCellText.text(try cell(id, as: .uuid)) == "6f9619ff-8b86-d011-b42d-00c04fc964ff")
    }

    @Test func timestampsRenderInUTC() throws {
        let date = Date(timeIntervalSince1970: 1_768_035_600) // 2026-01-10 09:00:00 UTC
        #expect(PostgresCellText.text(try cell(date, as: .timestamptz)) == "2026-01-10 09:00:00+00")
        let timestamp = PostgresCell(bytes: try cell(date, as: .timestamptz).bytes, dataType: .timestamp, format: .binary, columnName: "c", columnIndex: 0)
        #expect(PostgresCellText.text(timestamp) == "2026-01-10 09:00:00")
    }

    @Test func byteaIsHex() throws {
        #expect(PostgresCellText.text(try cell(ByteBuffer(bytes: [0xDE, 0xAD]), as: .bytea)) == "\\xdead")
    }

    @Test func textFormatCellsPassThrough() {
        let cell = PostgresCell(bytes: ByteBuffer(string: "{1,2}"), dataType: .int4Array, format: .text, columnName: "c", columnIndex: 0)
        #expect(PostgresCellText.text(cell) == "{1,2}")
    }
}
