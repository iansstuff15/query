import Foundation

/// Turns a pasted connection string into connection-form values, like TablePlus's
/// "Import from URL". Supports URLs, ADO.NET / JDBC (SQL Server), EZConnect / JDBC (Oracle),
/// and file URLs or paths (SQLite, DuckDB).
nonisolated enum ConnectionStringParser {
    static func parse(_ raw: String, for engine: DatabaseEngine) throws -> [ConnectionField: String] {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw ConnectionStringError.malformed }
        guard EngineCatalog.descriptor(for: engine).acceptsConnectionString else {
            throw ConnectionStringError.unsupportedEngine
        }
        switch engine {
        case .sqlServer:
            return try parseSQLServer(input)
        case .oracle:
            return try parseOracle(input)
        case .sqlite, .duckDB:
            return try parseFile(input, schemes: engine == .sqlite ? ["sqlite", "sqlite3", "file"] : ["duckdb", "file"])
        case .mongoDB:
            try requireScheme(of: input, in: ["mongodb", "mongodb+srv"])
            return [.url: input]
        case .libSQL:
            return try parseLibSQL(input)
        case .elasticsearch:
            return try parseElasticsearch(input)
        case .snowflake:
            return try parseSnowflake(input)
        case .bigQuery:
            return try parseBigQuery(input)
        case .redis:
            var values = try parseServerURL(input, schemes: ["redis", "rediss"])
            if values[.database] == nil { values[.database] = "0" }
            return values
        default:
            return try parseServerURL(input, schemes: schemes(for: engine))
        }
    }

    static func schemes(for engine: DatabaseEngine) -> [String] {
        switch engine {
        case .postgreSQL: ["postgres", "postgresql"]
        case .cockroachDB: ["postgres", "postgresql", "cockroachdb"]
        case .greenplum: ["postgres", "postgresql", "greenplum"]
        case .redshift: ["redshift", "postgres", "postgresql"]
        case .vertica: ["vertica"]
        case .mySQL: ["mysql"]
        case .mariaDB: ["mariadb", "mysql"]
        case .clickHouse: ["clickhouse", "http", "https"]
        case .cassandra: ["cassandra", "cql"]
        default: []
        }
    }

    // MARK: - Generic server URLs

    private static func parseServerURL(_ input: String, schemes: [String]) throws -> [ConnectionField: String] {
        let normalized = input.hasPrefix("jdbc:") ? String(input.dropFirst(5)) : input
        guard let components = URLComponents(string: normalized), let scheme = components.scheme?.lowercased() else {
            throw ConnectionStringError.malformed
        }
        guard schemes.contains(scheme) else {
            throw ConnectionStringError.schemeMismatch(expected: schemes, found: scheme)
        }
        guard let host = components.host, !host.isEmpty else { throw ConnectionStringError.malformed }
        var values: [ConnectionField: String] = [.host: host]
        values[.port] = components.port.map(String.init)
        values[.username] = components.user.flatMap(nonEmpty)
        values[.password] = components.password.flatMap(nonEmpty)
        let path = pathComponents(components)
        values[.database] = path.first
        values[.keyspace] = scheme == "cassandra" || scheme == "cql" ? path.first : nil
        if values[.keyspace] != nil { values[.database] = nil }
        values[.tlsMode] = tlsMode(scheme: scheme, query: components.queryItems ?? [])?.rawValue
        for item in components.queryItems ?? [] {
            switch item.name.lowercased() {
            case "user", "username": values[.username] = item.value.flatMap(nonEmpty) ?? values[.username]
            case "password": values[.password] = item.value.flatMap(nonEmpty) ?? values[.password]
            case "database", "dbname": values[.database] = item.value.flatMap(nonEmpty) ?? values[.database]
            default: break
            }
        }
        return values
    }

    private static func tlsMode(scheme: String, query: [URLQueryItem]) -> TLSMode? {
        if scheme == "rediss" || scheme == "https" { return .require }
        for item in query {
            let value = (item.value ?? "").lowercased()
            switch item.name.lowercased() {
            case "sslmode", "ssl-mode", "tls":
                switch value {
                case "disable", "disabled", "false", "allow": return .disable
                case "prefer", "preferred": return .prefer
                case "require", "required", "verify-ca", "verify-full", "verify_identity", "true": return .require
                default: continue
                }
            case "ssl", "secure":
                return ["1", "true", "yes"].contains(value) ? .require : .disable
            default:
                continue
            }
        }
        return nil
    }

    // MARK: - SQL Server

    private static func parseSQLServer(_ input: String) throws -> [ConnectionField: String] {
        if input.lowercased().hasPrefix("jdbc:sqlserver://") {
            return try parseSQLServerJDBC(String(input.dropFirst("jdbc:sqlserver://".count)))
        }
        if input.contains("://") {
            return try parseServerURL(input, schemes: ["sqlserver", "mssql"])
        }
        return try parseADO(input)
    }

    /// `Server=tcp:host,1433;Database=app;User Id=sa;Password=…;Encrypt=True`
    private static func parseADO(_ input: String) throws -> [ConnectionField: String] {
        let pairs = keyValuePairs(input, separator: ";")
        guard !pairs.isEmpty else { throw ConnectionStringError.malformed }
        var values: [ConnectionField: String] = [:]
        for (key, value) in pairs {
            switch key {
            case "server", "data source", "address", "addr", "network address":
                var server = value
                if server.lowercased().hasPrefix("tcp:") { server = String(server.dropFirst(4)) }
                let parts = server.split(separator: ",", maxSplits: 1).map(String.init)
                values[.host] = parts.first.flatMap(nonEmpty)
                values[.port] = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : nil
            case "database", "initial catalog": values[.database] = nonEmpty(value)
            case "user id", "uid", "user": values[.username] = nonEmpty(value)
            case "password", "pwd": values[.password] = nonEmpty(value)
            case "encrypt": values[.tlsMode] = encryptMode(value).rawValue
            default: break
            }
        }
        guard values[.host] != nil else { throw ConnectionStringError.malformed }
        return values
    }

    /// `host:1433;databaseName=app;user=sa;password=…;encrypt=false`
    private static func parseSQLServerJDBC(_ rest: String) throws -> [ConnectionField: String] {
        let segments = rest.split(separator: ";", omittingEmptySubsequences: true).map(String.init)
        guard let address = segments.first, !address.isEmpty else { throw ConnectionStringError.malformed }
        var values: [ConnectionField: String] = [:]
        let hostPort = address.split(separator: ":", maxSplits: 1).map(String.init)
        values[.host] = hostPort.first.map { $0.components(separatedBy: "\\").first ?? $0 }
        values[.port] = hostPort.count > 1 ? hostPort[1] : nil
        for (key, value) in keyValuePairs(segments.dropFirst().joined(separator: ";"), separator: ";") {
            switch key {
            case "databasename", "database": values[.database] = nonEmpty(value)
            case "user", "username": values[.username] = nonEmpty(value)
            case "password": values[.password] = nonEmpty(value)
            case "encrypt": values[.tlsMode] = encryptMode(value).rawValue
            default: break
            }
        }
        return values
    }

    private static func encryptMode(_ value: String) -> TLSMode {
        switch value.lowercased() {
        case "true", "yes", "mandatory", "strict": .require
        case "optional": .prefer
        default: .disable
        }
    }

    // MARK: - Oracle

    /// `user/password@host:port/service`, `jdbc:oracle:thin:@//host:port/service`, `oracle://…`
    private static func parseOracle(_ input: String) throws -> [ConnectionField: String] {
        if input.contains("://"), !input.lowercased().hasPrefix("jdbc:") {
            var values = try parseServerURL(input, schemes: ["oracle"])
            values[.serviceName] = values.removeValue(forKey: .database)
            values[.tlsMode] = nil
            return values
        }
        var rest = input
        var values: [ConnectionField: String] = [:]
        if rest.lowercased().hasPrefix("jdbc:oracle:thin:") {
            rest = String(rest.dropFirst("jdbc:oracle:thin:".count))
        }
        if let at = rest.lastIndex(of: "@") {
            let credentials = rest[..<at]
            if !credentials.isEmpty {
                let parts = credentials.split(separator: "/", maxSplits: 1).map(String.init)
                values[.username] = parts.first.flatMap(nonEmpty)
                values[.password] = parts.count > 1 ? nonEmpty(parts[1]) : nil
            }
            rest = String(rest[rest.index(after: at)...])
        }
        if rest.hasPrefix("//") { rest = String(rest.dropFirst(2)) }
        let addressAndService = rest.split(separator: "/", maxSplits: 1).map(String.init)
        guard let address = addressAndService.first, !address.isEmpty else { throw ConnectionStringError.malformed }
        let hostPort = address.split(separator: ":").map(String.init)
        values[.host] = hostPort.first
        if hostPort.count == 3 {
            // Legacy SID form host:port:SID
            values[.port] = hostPort[1]
            values[.serviceName] = hostPort[2]
        } else {
            values[.port] = hostPort.count > 1 ? hostPort[1] : nil
            values[.serviceName] = addressAndService.count > 1 ? nonEmpty(addressAndService[1]) : nil
        }
        return values
    }

    // MARK: - File engines

    private static func parseFile(_ input: String, schemes: [String]) throws -> [ConnectionField: String] {
        if input.hasPrefix("/") || input.hasPrefix("~") {
            return [.filePath: (input as NSString).expandingTildeInPath]
        }
        guard let colon = input.firstIndex(of: ":") else { throw ConnectionStringError.malformed }
        let scheme = input[..<colon].lowercased()
        guard schemes.contains(scheme) else {
            throw ConnectionStringError.schemeMismatch(expected: schemes, found: scheme)
        }
        var path = String(input[input.index(after: colon)...])
        while path.hasPrefix("//") { path.removeFirst() }
        if let query = path.firstIndex(of: "?") { path = String(path[..<query]) }
        path = path.removingPercentEncoding ?? path
        guard path.hasPrefix("/") || path.hasPrefix("~") else { throw ConnectionStringError.malformed }
        return [.filePath: (path as NSString).expandingTildeInPath]
    }

    // MARK: - URL-first engines

    private static func parseLibSQL(_ input: String) throws -> [ConnectionField: String] {
        guard var components = URLComponents(string: input), let scheme = components.scheme?.lowercased(),
              components.host != nil else { throw ConnectionStringError.malformed }
        let allowed = ["libsql", "http", "https", "wss", "ws"]
        guard allowed.contains(scheme) else { throw ConnectionStringError.schemeMismatch(expected: allowed, found: scheme) }
        var values: [ConnectionField: String] = [:]
        if let token = components.queryItems?.first(where: { $0.name == "authToken" })?.value {
            values[.apiToken] = token
            components.queryItems = components.queryItems?.filter { $0.name != "authToken" }
            if components.queryItems?.isEmpty == true { components.queryItems = nil }
        }
        values[.url] = components.string
        return values
    }

    private static func parseElasticsearch(_ input: String) throws -> [ConnectionField: String] {
        guard var components = URLComponents(string: input), let scheme = components.scheme?.lowercased(),
              components.host != nil else { throw ConnectionStringError.malformed }
        guard ["http", "https"].contains(scheme) else {
            throw ConnectionStringError.schemeMismatch(expected: ["http", "https"], found: scheme)
        }
        var values: [ConnectionField: String] = [:]
        values[.username] = components.user.flatMap(nonEmpty)
        values[.password] = components.password.flatMap(nonEmpty)
        components.user = nil
        components.password = nil
        values[.url] = components.string
        return values
    }

    /// `snowflake://user@account/database/schema?warehouse=WH&role=ROLE&token=…`
    private static func parseSnowflake(_ input: String) throws -> [ConnectionField: String] {
        guard let components = URLComponents(string: input), let scheme = components.scheme?.lowercased(),
              let account = components.host else { throw ConnectionStringError.malformed }
        guard scheme == "snowflake" else { throw ConnectionStringError.schemeMismatch(expected: ["snowflake"], found: scheme) }
        var values: [ConnectionField: String] = [.account: account]
        values[.username] = components.user.flatMap(nonEmpty)
        values[.apiToken] = components.password.flatMap(nonEmpty)
        let path = pathComponents(components)
        values[.database] = path.first
        values[.schema] = path.count > 1 ? path[1] : nil
        for item in components.queryItems ?? [] {
            switch item.name.lowercased() {
            case "warehouse": values[.warehouse] = item.value.flatMap(nonEmpty)
            case "role": values[.role] = item.value.flatMap(nonEmpty)
            case "token": values[.apiToken] = item.value.flatMap(nonEmpty)
            case "database", "db": values[.database] = item.value.flatMap(nonEmpty)
            case "schema": values[.schema] = item.value.flatMap(nonEmpty)
            default: break
            }
        }
        return values
    }

    /// `bigquery://project/dataset[?endpoint=http://localhost:9050]`
    private static func parseBigQuery(_ input: String) throws -> [ConnectionField: String] {
        guard let components = URLComponents(string: input), let scheme = components.scheme?.lowercased(),
              let project = components.host else { throw ConnectionStringError.malformed }
        guard scheme == "bigquery" else { throw ConnectionStringError.schemeMismatch(expected: ["bigquery"], found: scheme) }
        var values: [ConnectionField: String] = [.projectID: project]
        values[.dataset] = pathComponents(components).first
        values[.endpoint] = components.queryItems?.first { $0.name == "endpoint" }?.value
        return values
    }

    // MARK: - Helpers

    private static func requireScheme(of input: String, in schemes: [String]) throws {
        guard let colon = input.range(of: "://") else { throw ConnectionStringError.malformed }
        let scheme = input[..<colon.lowerBound].lowercased()
        guard schemes.contains(scheme) else { throw ConnectionStringError.schemeMismatch(expected: schemes, found: scheme) }
    }

    private static func pathComponents(_ components: URLComponents) -> [String] {
        components.path.split(separator: "/").map { $0.removingPercentEncoding ?? String($0) }.filter { !$0.isEmpty }
    }

    private static func keyValuePairs(_ input: String, separator: Character) -> [(String, String)] {
        input.split(separator: separator).compactMap { pair in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return (parts[0].trimmingCharacters(in: .whitespaces).lowercased(), parts[1].trimmingCharacters(in: .whitespaces))
        }
    }

    private static func nonEmpty(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }
}
