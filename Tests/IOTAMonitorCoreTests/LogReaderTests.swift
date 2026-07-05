import XCTest
@testable import IOTAMonitorCore

final class LogReaderTests: XCTestCase {

    private func makeTempDir() -> String {
        let dir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("iota-logreader-\(ProcessInfo.processInfo.globallyUniqueString)")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ dir: String, _ name: String, mtime: Date) {
        let p = (dir as NSString).appendingPathComponent(name)
        FileManager.default.createFile(atPath: p, contents: Data("x".utf8))
        try? FileManager.default.setAttributes([.modificationDate: mtime], ofItemAtPath: p)
    }

    /// The official app names its log by launch date and doesn't roll at midnight,
    /// so the newest-mtime file can be an "older-named" one. Pick by mtime.
    func testLatestPicksMostRecentlyWritten() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        // Yesterday's file is still the one being written today.
        write(dir, "2026-07-05-cli.log", mtime: Date(timeIntervalSince1970: 2_000_000))
        write(dir, "2026-07-04-cli.log", mtime: Date(timeIntervalSince1970: 1_000_000))
        write(dir, "2026-07-05-main.log", mtime: Date(timeIntervalSince1970: 9_000_000)) // not a cli log
        let latest = LogReader.latestLogPath(in: dir)
        XCTAssertEqual((latest as NSString?)?.lastPathComponent, "2026-07-05-cli.log")
    }

    func testLatestNilWhenNoCliLog() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        write(dir, "2026-07-05-main.log", mtime: Date(timeIntervalSince1970: 1_000_000))
        XCTAssertNil(LogReader.latestLogPath(in: dir))
    }
}
