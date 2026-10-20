import os

/// Internal logging. Never surface these messages to the user.
nonisolated enum AppLog {
    static let database = Logger(subsystem: AppConfig.logSubsystem, category: "database")
    static let keychain = Logger(subsystem: AppConfig.logSubsystem, category: "keychain")
    static let startup = Logger(subsystem: AppConfig.logSubsystem, category: "startup")
}
