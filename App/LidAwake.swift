import Foundation

/// Toggles macOS "keep awake with the lid closed" — `pmset disablesleep`, which
/// (unlike `caffeinate`) suppresses clamshell sleep so mining survives a closed
/// lid on battery. It is a persistent system setting, so it must be turned back
/// off explicitly. Enabling requires admin auth (prompted by osascript).
enum LidAwake {
    /// Current state, read from `pmset -g` (no privileges needed).
    static var isEnabled: Bool { parseSleepDisabled(from: run("/usr/bin/pmset", ["-g"]).out) }

    /// Parse `pmset -g` output. The line is `SleepDisabled\t\t1` — tab-separated,
    /// so we must split on tabs and spaces, not spaces alone.
    static func parseSleepDisabled(from pmsetOutput: String) -> Bool {
        for line in pmsetOutput.split(separator: "\n") where line.contains("SleepDisabled") {
            let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            return tokens.last.map(String.init) == "1"
        }
        return false
    }

    /// Set on all power sources. Returns false if auth was cancelled or it failed.
    @discardableResult
    static func setEnabled(_ on: Bool) -> Bool {
        let script = "do shell script \"pmset -a disablesleep \(on ? "1" : "0")\" with administrator privileges"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run(); p.waitUntilExit(); return p.terminationStatus == 0 }
        catch { return false }
    }

    private static func run(_ path: String, _ args: [String]) -> (status: Int32, out: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do {
            try p.run(); p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (p.terminationStatus, String(decoding: data, as: UTF8.self))
        } catch { return (-1, "") }
    }
}
