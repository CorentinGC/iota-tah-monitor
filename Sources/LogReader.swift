import Foundation

/// Resolves and tail-reads the IOTA "Train at Home" CLI log for the current day.
/// Read-only. Handles a missing/empty file and date rotation at midnight.
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

    enum ReadResult {
        case ok(text: String, mtime: Date)   // tail content + file modification time
        case empty                            // file exists but 0 bytes
        case missing                          // no file for today
    }

    /// Reads the last `tailBytes` of today's log without loading the whole file.
    static func readTail(path: String = todayLogPath()) -> ReadResult {
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
