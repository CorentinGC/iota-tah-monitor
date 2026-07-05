import Foundation

enum Phase: String {
    case off, starting, resetting, speedtest, queued, working, error, unknown
}

struct MinerState {
    var position: Int?
    var trendPerMin: Double?          // negative = advancing toward the front (good)
    var phase: Phase = .unknown
    var workLine: String?             // best-effort training/work description
    var speedtestOk: Bool?            // nil = not seen this window
    var queueStateErrors: Int = 0     // 503 "No handler for register.queue_state"
    var notFoundErrors: Int = 0       // 404 nginx on orchestrator endpoints
    var uptime: TimeInterval?
    var lastLogTime: Date?
    var lastRawLine: String = ""
}

extension MinerState {
    /// Estimated minutes until reaching the front of the queue (position 0),
    /// from the current position and the advance rate. `nil` when not queued or
    /// not advancing fast enough to estimate (a rough figure, rate is noisy).
    var etaMinutesToFront: Double? {
        guard phase == .queued, let pos = position, let trend = trendPerMin else { return nil }
        let advancePerMin = -trend                 // positive when the position drops
        guard advancePerMin >= 0.1 else { return nil }
        return Double(pos) / advancePerMin
    }
}

/// Turns a log tail into a MinerState. Defensive: anything unrecognized falls
/// back to the last raw line and never throws.
enum StateParser {
    /// Trend is computed over this recent slice of the tail, not the whole window.
    private static let recentTrendWindow: TimeInterval = 600   // 10 minutes

    private static let lineTimeFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    /// Leading `[yyyy-MM-dd HH:mm:ss.SSS]` timestamp of a log line, if present.
    private static func timestamp(of line: String) -> Date? {
        guard line.first == "[", let close = line.firstIndex(of: "]") else { return nil }
        let inner = String(line[line.index(after: line.startIndex)..<close])
        return lineTimeFmt.date(from: inner)
    }

    private static func firstInt(in line: String, after marker: String) -> Int? {
        guard let r = line.range(of: marker) else { return nil }
        let rest = line[r.upperBound...]
        var digits = ""
        for ch in rest {
            if ch.isNumber { digits.append(ch) }
            else if digits.isEmpty { continue }
            else { break }
        }
        return Int(digits)
    }

    static func parse(text: String, now: Date = Date()) -> MinerState {
        var s = MinerState()
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard !lines.isEmpty else { s.phase = .off; return s }

        // Position samples (value, time) to derive a trend.
        var samples: [(pos: Int, at: Date)] = []
        var lastSessionStart: Date?

        for line in lines {
            let t = timestamp(of: line)

            if let pos = firstInt(in: line, after: "'position':"), let at = t {
                samples.append((pos, at))
            }
            if line.contains("Starting miner"), let at = t {
                lastSessionStart = at   // most recent session start in window
            }
            if line.contains("Failed to run speedtest") {
                s.speedtestOk = false
            } else if line.contains("Running speedtest") && s.speedtestOk == nil {
                s.speedtestOk = true
            }
            if line.contains("register.queue_state") && line.contains("503") {
                s.queueStateErrors += 1
            }
            if line.contains("404") && line.contains("orchestrator request") {
                s.notFoundErrors += 1
            }
            if let work = workDescription(in: line) {
                s.workLine = work
            }
        }

        // Position + trend. Compute the trend over a RECENT window only: the tail
        // can span an hour and contain an older restart bump, whose first→last
        // slope washes out the current direction the user actually sees.
        if let last = samples.last {
            s.position = last.pos
            let cutoff = last.at.addingTimeInterval(-recentTrendWindow)
            let recent = samples.filter { $0.at >= cutoff }
            if let firstRecent = recent.first, recent.count >= 2 {
                let mins = last.at.timeIntervalSince(firstRecent.at) / 60.0
                if mins > 0.1 { s.trendPerMin = Double(last.pos - firstRecent.pos) / mins }
            }
        }

        // Timing.
        s.lastLogTime = timestamp(of: lines.last!) ?? now
        s.lastRawLine = strip(lines.last!)
        if let start = lastSessionStart, let last = s.lastLogTime {
            s.uptime = last.timeIntervalSince(start)
        }

        s.phase = derivePhase(state: s, lines: lines, now: now)
        return s
    }

    /// Best-effort detection of an active-training line. No such line has been
    /// observed yet, so these patterns are provisional.
    private static func workDescription(in line: String) -> String? {
        let markers = ["loss", "batch ", "layer ", "step ", "epoch ",
                       "activated", "assigned", "uploading", "downloading weights"]
        let lower = line.lowercased()
        guard markers.contains(where: lower.contains) else { return nil }
        return strip(line)
    }

    private static func derivePhase(state: MinerState, lines: [String], now: Date) -> Phase {
        // Stale log ⇒ off. Caller may still override to .off on missing file.
        if let last = state.lastLogTime, now.timeIntervalSince(last) > 120 { return .off }
        if state.workLine != nil { return .working }
        if state.position != nil { return .queued }
        let tailBlob = lines.suffix(20).joined(separator: "\n")
        if tailBlob.contains("Running speedtest") { return .speedtest }
        if tailBlob.contains("Resetting miner") || tailBlob.contains("resetting") { return .resetting }
        if tailBlob.contains("Starting miner") || tailBlob.contains("Miner Ready") { return .starting }
        return .unknown
    }

    /// Drops the `[time] [level]  timestamp | LEVEL | module - ` prefixes,
    /// leaving the human-readable tail of a log line.
    private static func strip(_ line: String) -> String {
        if let r = line.range(of: " - ", options: .backwards) {
            return String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        if let close = line.firstIndex(of: "]") {
            var rest = String(line[line.index(after: close)...])
            if let close2 = rest.firstIndex(of: "]") { rest = String(rest[rest.index(after: close2)...]) }
            return rest.trimmingCharacters(in: .whitespaces)
        }
        return line.trimmingCharacters(in: .whitespaces)
    }
}
