import XCTest
@testable import IOTAMonitorCore

final class StateParserTests: XCTestCase {

    /// Same format/timezone StateParser uses, so fixtures and `now` align
    /// regardless of the machine's locale.
    private func date(_ s: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f.date(from: s)!
    }

    // Real-shaped queued log: two position samples, a speedtest failure,
    // one 404 orchestrator error, one 503 queue_state error.
    private let queuedLog = """
    [2026-07-05 17:43:45.762] [info]  2026-07-05 17:43:45.762 | INFO | miner.new_miner:run_miner:1723 - 🚀 Starting miner 🚀
    [2026-07-05 17:43:49.908] [info]  2026-07-05 17:43:49.908 | DEBUG | miner.utils.utils:run_speedtest:84 - Failed to run speedtest: Unable to connect to servers to test latency.
    [2026-07-05 17:45:06.885] [info]  2026-07-05 17:45:06.885 | ERROR | subnet.common_api_client:orchestrator_request:92 - Error making orchestrator request to endpoint /miner/register/status/abc: 404 - <html>
    [2026-07-05 17:45:09.171] [info]  2026-07-05 17:45:09.171 | DEBUG | subnet.common_api_client:orchestrator_request:84 - Successfully completed request; response: {'queue_id': 'abc', 'status': 'queued', 'position': 1587, 'poll_after': 60}
    [2026-07-05 17:45:21.200] [info]  2026-07-05 17:45:21.200 | WARNING | miner.utils.node_control_mixin:register_set_queue_state:221 - register_set_queue_state exhausted retries (3): POST /register/queue_state failed 503: {"detail":"unsupported: No handler for register.queue_state"}
    [2026-07-05 17:46:12.398] [info]  2026-07-05 17:46:12.398 | DEBUG | subnet.common_api_client:orchestrator_request:84 - Successfully completed request; response: {'queue_id': 'abc', 'status': 'queued', 'position': 1583, 'poll_after': 60}
    """

    func testQueuedStateParsesPositionAndTrend() {
        let s = StateParser.parse(text: queuedLog, now: date("2026-07-05 17:46:20.000"))
        XCTAssertEqual(s.phase, .queued)
        XCTAssertEqual(s.position, 1583)                 // last sample wins
        XCTAssertNotNil(s.trendPerMin)
        XCTAssertLessThan(s.trendPerMin!, 0)             // 1587 → 1583 = advancing
        XCTAssertNil(s.workLine)                         // never assigned
    }

    func testSpeedtestAndBackendCounters() {
        let s = StateParser.parse(text: queuedLog, now: date("2026-07-05 17:46:20.000"))
        XCTAssertEqual(s.speedtestOk, false)
        XCTAssertEqual(s.queueStateErrors, 1)
        XCTAssertEqual(s.notFoundErrors, 1)
    }

    func testUptimeFromSessionStart() {
        let s = StateParser.parse(text: queuedLog, now: date("2026-07-05 17:46:20.000"))
        // 17:43:45 → 17:46:12 ≈ 147 s
        XCTAssertNotNil(s.uptime)
        XCTAssertGreaterThan(s.uptime!, 140)
        XCTAssertLessThan(s.uptime!, 160)
    }

    func testQueueEtaFromAdvanceRate() {
        // 1587 → 1583 over ~63 s ≈ -3.8/min → ETA ≈ 1583 / 3.8 ≈ 416 min.
        let s = StateParser.parse(text: queuedLog, now: date("2026-07-05 17:46:20.000"))
        let eta = s.etaMinutesToFront
        XCTAssertNotNil(eta)
        XCTAssertGreaterThan(eta!, 300)
        XCTAssertLessThan(eta!, 550)
    }

    func testNoEtaWhenNotAdvancing() {
        // Two identical positions → trend ~0 → no ETA.
        let flat = """
        [2026-07-05 17:45:00.000] [info]  x - response: {'status': 'queued', 'position': 1500}
        [2026-07-05 17:46:00.000] [info]  x - response: {'status': 'queued', 'position': 1500}
        """
        let s = StateParser.parse(text: flat, now: date("2026-07-05 17:46:10.000"))
        XCTAssertEqual(s.phase, .queued)
        XCTAssertNil(s.etaMinutesToFront)
    }

    func testTrendUsesRecentWindowNotWholeTail() {
        // Older restart bump (up to 1564) then a steady recent descent. First→last
        // of the whole tail is nearly flat, but the recent trend is clearly down.
        let log = """
        [2026-07-05 17:48:00.000] [info]  x - response: {'status': 'queued', 'position': 1554}
        [2026-07-05 17:52:00.000] [info]  x - response: {'status': 'queued', 'position': 1564}
        [2026-07-05 17:55:00.000] [info]  x - response: {'status': 'queued', 'position': 1560}
        [2026-07-05 17:57:00.000] [info]  x - response: {'status': 'queued', 'position': 1558}
        [2026-07-05 17:58:00.000] [info]  x - response: {'status': 'queued', 'position': 1556}
        [2026-07-05 17:59:00.000] [info]  x - response: {'status': 'queued', 'position': 1554}
        [2026-07-05 17:59:40.000] [info]  x - response: {'status': 'queued', 'position': 1553}
        """
        let s = StateParser.parse(text: log, now: date("2026-07-05 18:00:00.000"))
        XCTAssertEqual(s.position, 1553)
        XCTAssertNotNil(s.trendPerMin)
        XCTAssertLessThan(s.trendPerMin!, -0.5)   // recent descent, not the flat whole-tail slope
    }

    func testUnrecognizedStructuralLinesCaptureOnlyNewShapes() {
        let log = """
        [t] x | DEBUG | subnet.common_api_client:req:33 - Making orchestrator request | method: GET
        [t] x | INFO  | miner.pool.miner:run:1 - response: {'status': 'queued', 'position': 1500}
        [t] x | INFO  | miner.trainer:run:88 - fwd_pass shard=3 microstep=42 grad_norm=1.7
        [t] x | INFO  | miner.trainer:run:88 - fwd_pass shard=3 microstep=43 grad_norm=1.6
        plain non-structural line without the separator
        """
        let items = StateParser.unrecognizedStructuralLines(in: log)
        // orchestrator + queued recognized; the two fwd_pass lines share a template.
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items[0].sample.contains("fwd_pass"))
        XCTAssertTrue(items[0].template.contains("#"))   // digits templated
    }

    func testStaleLogFallsBackToOff() {
        // Same log read 24 min later: last line is older than the 120 s threshold.
        let s = StateParser.parse(text: queuedLog, now: date("2026-07-05 18:10:00.000"))
        XCTAssertEqual(s.phase, .off)
    }

    func testEmptyLogIsOff() {
        let s = StateParser.parse(text: "", now: date("2026-07-05 17:46:20.000"))
        XCTAssertEqual(s.phase, .off)
        XCTAssertNil(s.position)
    }

    func testWorkLineDetectedWhenTraining() {
        let log = """
        [2026-07-05 18:00:00.000] [info]  2026-07-05 18:00:00.000 | INFO | miner.train:step:10 - layer 3 step 42 loss=1.2345
        """
        let s = StateParser.parse(text: log, now: date("2026-07-05 18:00:05.000"))
        XCTAssertEqual(s.phase, .working)
        XCTAssertNotNil(s.workLine)
        XCTAssertTrue(s.workLine!.contains("loss=1.2345"))
    }
}
