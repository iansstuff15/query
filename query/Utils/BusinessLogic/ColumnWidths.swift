import Foundation

/// Column widths for the data grid, from the longest of each column's name and values (a sample
/// of rows, so huge results stay fast). The grid uses a monospaced font, so width is characters
/// times one character's width.
nonisolated enum ColumnWidths {
    static func widths(
        for result: QueryResult, characterWidth: Double, padding: Double, range: ClosedRange<Double>, sampleSize: Int = 200
    ) -> [Double] {
        let sample = result.rows.prefix(sampleSize)
        return result.columns.map { column in
            let longest = sample.reduce(column.name.count) { longest, row in
                max(longest, (row[column] ?? "NULL").count)
            }
            return min(max(Double(longest) * characterWidth + padding, range.lowerBound), range.upperBound)
        }
    }

    /// Stretches `widths` to fill `available` when they're narrower, sharing the extra space in
    /// proportion to each column's width (like a native table filling its view). Wider sets are
    /// left as they are and scroll.
    static func filling(_ widths: [Double], to available: Double) -> [Double] {
        let total = widths.reduce(0, +)
        guard total > 0, available > total else { return widths }
        let scale = available / total
        return widths.map { $0 * scale }
    }
}
