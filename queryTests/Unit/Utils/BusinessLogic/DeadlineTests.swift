import Testing
@testable import query

@Suite("Deadline")
struct DeadlineTests {
    @Test func returnsTheResultWhenWorkFinishesInTime() async throws {
        #expect(try await Deadline.run(.seconds(5)) { 42 } == 42)
    }

    @Test func passesThroughTheWorksError() async {
        await #expect(throws: MockError.self) {
            try await Deadline.run(.seconds(5)) { () async throws -> Int in throw MockError() }
        }
    }

    @Test func timesOutEvenWhenTheWorkIgnoresCancellation() async {
        let gate = Gate()
        await #expect(throws: DatabaseError.timedOut) {
            try await Deadline.run(.milliseconds(20)) { await gate.pass() }
        }
        await gate.open()
    }
}
