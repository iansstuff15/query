import Foundation
import Testing
@testable import query

@Suite("SQLBatchSummary")
struct SQLBatchSummaryTests {
    private func entry(_ succeeded: Bool, ms: Int) -> SQLBatchSummary.Entry {
        .init(id: UUID(), resultID: "q", sql: "q", summary: .init(succeeded: succeeded, duration: .milliseconds(ms), rowCount: nil, errorMessage: nil))
    }

    @Test func succeedsOnlyWhenEveryRequestedStatementSucceeded() {
        #expect(SQLBatchSummary(entries: [entry(true, ms: 1), entry(true, ms: 2)], requestedCount: 2).succeeded)
        #expect(!SQLBatchSummary(entries: [entry(true, ms: 1), entry(false, ms: 2)], requestedCount: 3).succeeded)
        #expect(!SQLBatchSummary(entries: [entry(true, ms: 1)], requestedCount: 2).succeeded)
    }

    @Test func totalsAndSkips() {
        let batch = SQLBatchSummary(entries: [entry(true, ms: 5), entry(false, ms: 7)], requestedCount: 4)
        #expect(batch.duration == .milliseconds(12))
        #expect(batch.skippedCount == 2)
    }
}
