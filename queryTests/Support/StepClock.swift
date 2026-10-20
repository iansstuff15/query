import Foundation
import Synchronization

/// A clock that moves forward by `step` each time it's read, so timed code measures a known duration.
final class StepClock: Clock, Sendable {
    struct Instant: InstantProtocol {
        let offset: Duration

        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
    }

    private let step: Duration
    private let current = Mutex(Duration.zero)

    init(step: Duration) {
        self.step = step
    }

    var now: Instant {
        current.withLock { value in
            defer { value += step }
            return Instant(offset: value)
        }
    }

    var minimumResolution: Duration { .nanoseconds(1) }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {}
}
