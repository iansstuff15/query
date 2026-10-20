import Foundation
import Testing
@testable import query

private struct FakeCheck: StartupCheck {
    let id: StartupCheckID
    let outcome: StartupCheckOutcome
    func run() async -> StartupCheckOutcome { outcome }
}

@MainActor
@Suite("SplashViewModel")
struct SplashViewModelTests {
    @Test func runsChecksInOrderAndFinishes() async {
        let model = SplashViewModel(checks: [
            FakeCheck(id: .sqlite, outcome: .passed(detail: "3.46")),
            FakeCheck(id: .network, outcome: .degraded(reason: "offline")),
        ], minimumDuration: .zero)
        #expect(model.order == [.sqlite, .network])
        #expect(model.progress == 0)
        #expect(model.states[.sqlite] == .pending)
        await model.run()
        #expect(model.isFinished)
        #expect(model.progress == 1)
        #expect(model.current == nil)
        #expect(model.states[.sqlite] == .finished(.passed(detail: "3.46")))
        #expect(model.degradedCount == 1)
    }

    @Test func emptyCheckListIsComplete() async {
        let model = SplashViewModel(checks: [], minimumDuration: .zero)
        #expect(model.progress == 1)
        await model.run()
        #expect(model.isFinished)
    }
}
