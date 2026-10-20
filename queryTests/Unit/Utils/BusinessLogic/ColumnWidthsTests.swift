import Testing
@testable import query

@Suite("ColumnWidths")
struct ColumnWidthsTests {
    private let result = QueryResult(columnNames: ["id", "email"], values: [["1", "ada@example.com"], ["2", nil], ["10", "a"]])

    @Test func fitTheLongestNameOrValue() {
        let widths = ColumnWidths.widths(for: result, characterWidth: 10, padding: 4, range: 0...1_000)
        #expect(widths == [24, 154]) // "id" / "10" = 2 chars; "ada@example.com" = 15 chars
    }

    @Test func nullCountsAsItsLabel() {
        let nulls = QueryResult(columnNames: ["x"], values: [[nil]])
        #expect(ColumnWidths.widths(for: nulls, characterWidth: 10, padding: 0, range: 0...1_000) == [40])
    }

    @Test func clampedToTheRange() {
        #expect(ColumnWidths.widths(for: result, characterWidth: 10, padding: 4, range: 50...100) == [50, 100])
    }

    @Test func onlyASampleOfRowsIsMeasured() {
        let rows: [[String?]] = [["a"], ["a"], ["a much longer value"]]
        #expect(ColumnWidths.widths(for: QueryResult(columnNames: ["c"], values: rows), characterWidth: 1, padding: 0, range: 0...1_000, sampleSize: 2) == [1])
    }

    @Test func narrowColumnsStretchToFillTheView() {
        #expect(ColumnWidths.filling([100, 300], to: 800) == [200, 600])
    }

    @Test func wideColumnsAreLeftToScroll() {
        #expect(ColumnWidths.filling([500, 500], to: 800) == [500, 500])
        #expect(ColumnWidths.filling([], to: 800) == [])
    }
}
