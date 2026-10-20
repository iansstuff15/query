import Foundation
import Testing
@testable import query

@Suite("InfoPlist")
struct InfoPlistTests {
    @Test func integersAreReadAndClamped() {
        let info: [String: Any] = ["A": 50, "B": "75", "C": 99_999, "D": -3, "E": "x"]
        #expect(InfoPlist.int("A", default: 1, in: 1...100, info: info) == 50)
        #expect(InfoPlist.int("B", default: 1, in: 1...100, info: info) == 75)
        #expect(InfoPlist.int("C", default: 1, in: 1...100, info: info) == 100)
        #expect(InfoPlist.int("D", default: 1, in: 1...100, info: info) == 1)
        #expect(InfoPlist.int("E", default: 7, in: 1...100, info: info) == 7)
        #expect(InfoPlist.int("missing", default: 7, in: 1...100, info: info) == 7)
    }

    @Test func booleansAcceptPlistAndBuildSettingSpellings() {
        let info: [String: Any] = ["A": true, "B": "NO", "C": "1", "D": "maybe", "E": 0]
        #expect(InfoPlist.bool("A", default: false, info: info))
        #expect(!InfoPlist.bool("B", default: true, info: info))
        #expect(InfoPlist.bool("C", default: false, info: info))
        #expect(InfoPlist.bool("D", default: true, info: info))
        #expect(!InfoPlist.bool("E", default: true, info: info))
        #expect(InfoPlist.bool("missing", default: true, info: info))
    }

    @Test func theAppsInfoPlistSetsEveryValue() {
        let info = InfoPlist.main
        for key in ["ROW_LIMIT", "OPEN_ANYTHING_RESULT_LIMIT", "SPLASH_MINIMUM_MILLISECONDS", "CONNECTION_CHECK_TIMEOUT_SECONDS",
                    "SQL_HISTORY_LIMIT", "SQL_COMPLETION_LIMIT", "SQL_FILE_MAX_MEGABYTES"] {
            #expect(info[key] != nil, "\(key) is missing from query-Info.plist")
        }
        #expect(AppConfig.rowLimit == 300)
        #expect(AppConfig.sqlFileMaxBytes == 5_000_000)
        #expect(AppConfig.connectionCheckTimeout == .seconds(5))
    }
}
