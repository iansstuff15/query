import Foundation
import MySQLNIO
import NIOCore
import Testing
@testable import query

@Suite("MySQLCellText")
struct MySQLCellTextTests {
    @Test func binaryDateTimesRenderAsText() throws {
        let datetime = try #require(MySQLTime(year: 2026, month: 1, day: 10, hour: 9, minute: 0, second: 0).mysqlData)
        #expect(MySQLCellText.text(datetime) == "2026-01-10 09:00:00")
        let precise = try #require(MySQLTime(year: 2026, month: 1, day: 10, hour: 9, minute: 0, second: 1, microsecond: 250).mysqlData)
        #expect(MySQLCellText.text(precise) == "2026-01-10 09:00:01.000250")
    }

    @Test func numbersAndStrings() {
        #expect(MySQLCellText.text(MySQLData(int: 42)) == "42")
        #expect(MySQLCellText.text(MySQLData(double: 1.5)) == "1.5")
        #expect(MySQLCellText.text(MySQLData(string: "Ada Lovelace")) == "Ada Lovelace")
    }

    @Test func decimalsPassThroughAsText() {
        let decimal = MySQLData(type: .newdecimal, format: .binary, buffer: ByteBuffer(string: "329.99"), isUnsigned: false)
        #expect(MySQLCellText.text(decimal) == "329.99")
    }

    @Test func nullIsNil() {
        #expect(MySQLCellText.text(.null) == nil)
    }
}
