import Foundation

/// Tracks the official app's version so we can flag "it updated — the log format
/// may have changed, re-verify parsing" (the log-format-watcher's cue). The app
/// can't run the Claude agent itself; it surfaces the signal and the human runs it.
enum VersionWatch {
    private static let key = "official.version.acked"

    static var current: String? { OfficialApp.version }

    private static var acked: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// First run records the current version silently; later a mismatch means it updated.
    static func seedIfNeeded() {
        if acked == nil, let c = current { acked = c }
    }

    /// (from, to) when the installed version differs from what we acknowledged.
    static var change: (from: String, to: String)? {
        guard let a = acked, let c = current, a != c else { return nil }
        return (a, c)
    }

    /// Mark the current version as verified — clears the warning.
    static func acknowledge() { acked = current }
}
