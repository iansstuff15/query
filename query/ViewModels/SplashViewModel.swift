import Foundation
import Observation
import os

/// Runs the startup checks in order while the splash screen is up.
@MainActor
@Observable
final class SplashViewModel {
    private(set) var states: [StartupCheckID: StartupCheckState]
    private(set) var current: StartupCheckID?
    private(set) var isFinished = false

    private let checks: [any StartupCheck]
    /// Keeps the splash readable on fast machines; tests pass `.zero`.
    private let minimumDuration: Duration
    private let clock = ContinuousClock()

    init(checks: [any StartupCheck], minimumDuration: Duration) {
        self.checks = checks
        self.minimumDuration = minimumDuration
        states = Dictionary(uniqueKeysWithValues: checks.map { ($0.id, .pending) })
    }

    var order: [StartupCheckID] { checks.map(\.id) }

    /// Fraction of checks finished, 0…1.
    var progress: Double {
        guard !checks.isEmpty else { return 1 }
        let done = states.values.filter { if case .finished = $0 { true } else { false } }.count
        return Double(done) / Double(checks.count)
    }

    var degradedCount: Int {
        states.values.filter { if case .finished(.degraded) = $0 { true } else { false } }.count
    }

    func run() async {
        guard !isFinished else { return }
        let started = clock.now
        for check in checks {
            current = check.id
            states[check.id] = .running
            let outcome = await check.run()
            states[check.id] = .finished(outcome)
            if case .degraded(let reason) = outcome {
                AppLog.startup.error("Startup check \(check.id.rawValue, privacy: .public) degraded: \(reason, privacy: .private)")
            } else {
                AppLog.startup.info("Startup check \(check.id.rawValue, privacy: .public) passed")
            }
        }
        current = nil
        let remaining = minimumDuration - started.duration(to: clock.now)
        if remaining > .zero {
            try? await clock.sleep(for: remaining)
        }
        isFinished = true
    }
}
