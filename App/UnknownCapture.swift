import Foundation

/// Opt-in debug helper: persists each *new shape* of unrecognized structural log
/// line to our own file, so that once the miner is finally assigned we capture
/// the real training-line formats needed to extend `StateParser.workDescription`.
/// Writes only to our own log dir, never the official app's logs.
enum UnknownCapture {
    static let dir = ("~/Library/Logs/IOTA Monitor" as NSString).expandingTildeInPath
    static let file = (dir as NSString).appendingPathComponent("unknown-lines.log")

    /// Persisted across launches via UserDefaults.
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "capture.unknown") }
        set { UserDefaults.standard.set(newValue, forKey: "capture.unknown") }
    }

    private static var seen = Set<String>()
    private static var seeded = false

    /// Append any not-yet-seen line shapes found in `text`.
    static func capture(from text: String) {
        seedIfNeeded()
        let fresh = StateParser.unrecognizedStructuralLines(in: text)
            .filter { seen.insert($0.template).inserted }
            .map { $0.sample }
        guard !fresh.isEmpty else { return }
        append(fresh)
    }

    /// Rebuild the seen-template set from the existing file so restarts don't
    /// re-append shapes we already captured.
    private static func seedIfNeeded() {
        guard !seeded else { return }
        seeded = true
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        guard let existing = try? String(contentsOfFile: file, encoding: .utf8) else { return }
        for line in existing.split(separator: "\n") {
            seen.insert(String(line.map { $0.isNumber ? "#" : $0 }))
        }
    }

    private static func append(_ lines: [String]) {
        let blob = lines.joined(separator: "\n") + "\n"
        guard let data = blob.data(using: .utf8) else { return }
        if let h = FileHandle(forWritingAtPath: file) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: data)
        } else {
            try? data.write(to: URL(fileURLWithPath: file))
        }
    }
}
