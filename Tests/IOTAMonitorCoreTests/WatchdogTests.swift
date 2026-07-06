import XCTest
@testable import IOTAMonitorCore

final class WatchdogTests: XCTestCase {
    private func input(enabled: Bool = true, appRunning: Bool = true, orphanAlive: Bool = false,
                       logStaleSeconds: Double? = 0, recentlyUp: Bool = true,
                       sinceLast: Double? = nil) -> WatchdogInput {
        WatchdogInput(enabled: enabled, appRunning: appRunning, orphanAlive: orphanAlive,
                      logStaleSeconds: logStaleSeconds, recentlyUp: recentlyUp, secondsSinceLastAction: sinceLast)
    }

    func testDisabledDoesNothing() {
        XCTAssertEqual(Watchdog.decide(input(enabled: false, appRunning: false, orphanAlive: true)), .none)
    }

    func testNotRecentlyUpDoesNothing() {
        // App down + orphans, but it wasn't up recently → user keeps it off; don't launch.
        XCTAssertEqual(Watchdog.decide(input(appRunning: false, orphanAlive: true, recentlyUp: false)), .none)
    }

    func testCrashRelaunches() {
        XCTAssertEqual(Watchdog.decide(input(appRunning: false, orphanAlive: true)), .relaunch)
    }

    func testCleanQuitLeftAlone() {
        // Down, no orphans = clean quit → leave it.
        XCTAssertEqual(Watchdog.decide(input(appRunning: false, orphanAlive: false)), .none)
    }

    func testZombieRestarts() {
        XCTAssertEqual(Watchdog.decide(input(appRunning: true, logStaleSeconds: 600)), .restart)
    }

    func testHealthyDoesNothing() {
        XCTAssertEqual(Watchdog.decide(input(appRunning: true, logStaleSeconds: 30)), .none)
    }

    func testBackoffThrottles() {
        // Zombie condition, but we just acted → wait.
        XCTAssertEqual(Watchdog.decide(input(appRunning: true, logStaleSeconds: 600, sinceLast: 60)), .none)
    }
}
