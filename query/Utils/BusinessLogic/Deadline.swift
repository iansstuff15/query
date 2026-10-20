import Foundation
import Synchronization

/// Runs async work with a time limit.
nonisolated enum Deadline {
    /// Returns `operation`'s result, or throws `DatabaseError.timedOut` once `timeout` passes.
    /// Returns as soon as the limit is hit, even if the work ignores cancellation (a socket connect
    /// can); that work is cancelled and left to finish in the background.
    static func run<T: Sendable>(
        _ timeout: Duration, operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let outcome = Outcome<T>()
        let work = Task { outcome.finish(await Result(asyncCatching: operation)) }
        let timer = Task {
            try? await Task.sleep(for: timeout)
            outcome.finish(.failure(DatabaseError.timedOut))
        }
        defer {
            work.cancel()
            timer.cancel()
        }
        return try await withTaskCancellationHandler {
            try await outcome.value()
        } onCancel: {
            outcome.finish(.failure(CancellationError()))
        }
    }

    /// The first result wins; later ones are dropped.
    private final class Outcome<T: Sendable>: Sendable {
        private struct State {
            var result: Result<T, any Error>?
            var waiter: CheckedContinuation<T, any Error>?
        }

        private let state = Mutex(State())

        func finish(_ result: Result<T, any Error>) {
            let waiter: CheckedContinuation<T, any Error>? = state.withLock { state in
                guard state.result == nil else { return nil }
                state.result = result
                defer { state.waiter = nil }
                return state.waiter
            }
            waiter?.resume(with: result)
        }

        func value() async throws -> T {
            try await withCheckedThrowingContinuation { continuation in
                let ready: Result<T, any Error>? = state.withLock { state in
                    if state.result == nil { state.waiter = continuation }
                    return state.result
                }
                if let ready { continuation.resume(with: ready) }
            }
        }
    }
}

private extension Result where Failure == any Error {
    nonisolated init(asyncCatching body: () async throws -> Success) async {
        do { self = .success(try await body()) } catch { self = .failure(error) }
    }
}
