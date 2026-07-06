import AppKit

/// Controls the official "IOTA Train at Home" app lifecycle from our menu bar:
/// launch / quit / restart. We never modify or bypass it — the official signed
/// app keeps doing the mining and the Secure Enclave signing. We only start and
/// stop it, and reap the `main_pool` workers it orphans on quit (a bug in its
/// own cleanup: its will-quit handler fails to kill the worker).
enum OfficialApp {
    static let bundleId = "com.electron.iota-train-at-home"
    static let displayName = "IOTA Train at Home"

    /// True when the official app is currently running.
    static var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleId }
    }

    private static var runningApp: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleId }
    }

    /// Short version string from the installed app bundle, if found.
    static var version: String? {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
            ?? URL(fileURLWithPath: "/Applications/\(displayName).app")
        return Bundle(url: url)?.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    /// True when a `main_pool` worker is alive while the app is not — the orphan bug.
    static func orphanWorkerAlive() -> Bool {
        run("/usr/bin/pgrep", ["-f", "main_pool"]).status == 0
    }

    /// Launch it unobtrusively: background (`-g`) and hidden (`-j`) so the heavy
    /// Chromium window/renderer stays out of the way. Our menu bar is the UI.
    static func launch() {
        _ = run("/usr/bin/open", ["-gj", "-a", displayName])
    }

    /// Graceful quit, then reap any worker it leaves behind.
    static func quit() {
        runningApp?.terminate()
        reapOrphansSoon()
    }

    static func restart() {
        runningApp?.terminate()
        // Wait for the app + its worker to die, then relaunch.
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            reapOrphans()
            DispatchQueue.main.async { launch() }
        }
    }

    /// Kill leftover workers (fixes the official app's orphan-on-quit bug).
    static func reapOrphans() {
        _ = run("/usr/bin/pkill", ["-f", "main_pool"])
    }

    private static func reapOrphansSoon() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { reapOrphans() }
    }

    @discardableResult
    private static func run(_ path: String, _ args: [String]) -> (status: Int32, out: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do {
            try p.run(); p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (p.terminationStatus, String(decoding: data, as: UTF8.self))
        } catch {
            return (-1, "")
        }
    }
}
