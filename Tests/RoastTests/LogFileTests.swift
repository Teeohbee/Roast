import Foundation
@testable import RoastKit

enum LogFileTests {
    static func withTempDirectory(_ body: (URL) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("roast-logfile-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        try body(dir)
    }

    static func contents(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    static func run() {
        let date = ISO8601DateFormatter().date(from: "2026-11-23T16:30:00Z")!

        suite("LogFile") {
            test("appends a timestamped line, creating the directory") {
                try withTempDirectory { dir in
                    let log = LogFile(url: dir.appendingPathComponent("Roast/roast.log"), maxBytes: 1000)
                    log.append("first", at: date)
                    log.append("second", at: date)
                    try expect(contents(log.url), "2026-11-23T16:30:00Z first\n2026-11-23T16:30:00Z second\n")
                }
            }

            test("rolls over to .1 once the file passes its size cap") {
                try withTempDirectory { dir in
                    let log = LogFile(url: dir.appendingPathComponent("roast.log"), maxBytes: 50)
                    log.append(String(repeating: "x", count: 40), at: date)
                    log.append("after", at: date)
                    try expect(contents(log.url), "2026-11-23T16:30:00Z after\n")
                    try expect(contents(dir.appendingPathComponent("roast.log.1")).hasSuffix("xxxx\n"), "previous log kept in roast.log.1")
                }
            }
        }
    }
}
