import Foundation

/// Resolves and tail-reads the IOTA "Train at Home" CLI log. Read-only. Handles a
/// missing/empty file. The official app names its log by launch date and does NOT
/// roll over at midnight, so a session started yesterday keeps writing to
/// yesterday's file today — we therefore read the most recently written log, not
/// strictly today's.
struct LogReader {
    static let logDir = ("~/Library/Logs/IOTA Train at Home" as NSString).expandingTildeInPath
    static let tailBytes = 64 * 1024

    /// Path of today's cli.log (e.g. 2026-07-05-cli.log).
    static func todayLogPath(now: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        return (logDir as NSString).appendingPathComponent("\(fmt.string(from: now))-cli.log")
    }

    /// The most recently modified `*-cli.log` in `dir` — the one being written now.
    /// nil when the directory can't be listed or holds no cli log.
    static func latestLogPath(in dir: String = logDir) -> String? {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: dir) else { return nil }
        let candidates = items.filter { $0.hasSuffix("-cli.log") }.compactMap { name -> (String, Date)? in
            let p = (dir as NSString).appendingPathComponent(name)
            guard let d = (try? fm.attributesOfItem(atPath: p)[.modificationDate]) as? Date else { return nil }
            return (p, d)
        }
        return candidates.max { $0.1 < $1.1 }?.0
    }

    /// The log to read now: the latest written one, falling back to today's name.
    static func currentLogPath() -> String { latestLogPath() ?? todayLogPath() }

    enum ReadResult {
        case ok(text: String, mtime: Date)   // tail content + file modification time
        case empty                            // file exists but 0 bytes
        case missing                          // no cli log found
    }

    /// Reads the last `tailBytes` of the current log without loading the whole file.
    static func readTail(path: String = currentLogPath()) -> ReadResult {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return .missing }

        guard let handle = FileHandle(forReadingAtPath: path) else { return .missing }
        defer { try? handle.close() }

        let attrs = try? fm.attributesOfItem(atPath: path)
        let size = (attrs?[.size] as? UInt64) ?? 0
        let mtime = (attrs?[.modificationDate] as? Date) ?? Date.distantPast
        guard size > 0 else { return .empty }

        let offset = size > UInt64(tailBytes) ? size - UInt64(tailBytes) : 0
        try? handle.seek(toOffset: offset)
        let data = (try? handle.readToEnd()) ?? Data()
        let text = String(decoding: data, as: UTF8.self)
        return .ok(text: text, mtime: mtime)
    }
}
