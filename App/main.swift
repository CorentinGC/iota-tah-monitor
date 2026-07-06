import AppKit
import ServiceManagement

/// Menu bar app: reads the IOTA T@H CLI log every few seconds and renders the
/// real queue position / state / work status the official UI fails to show.
final class MenuBarApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private let refresh: TimeInterval = 5
    private let prefs = PreferencesWindowController()

    // Watchdog runtime state (decision logic is in core `Watchdog`).
    private var lastSeenRunningAt: Date?
    private var lastWatchdogActionAt: Date?
    private var recentWatchdogActions: [Date] = []
    private var watchdogFlapped = false

    func applicationDidFinishLaunching(_ note: Notification) {
        VersionWatch.seedIfNeeded()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⛏ …"
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: refresh, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        // One process check per tick: pgrep for orphans only when the app is down.
        let running = OfficialApp.isRunning
        let orphan = running ? false : OfficialApp.orphanWorkerAlive()
        let state = read(capture: UnknownCapture.isEnabled)
        if let b = statusItem.button {
            b.image = dot(statusColor(for: state.phase))
            b.imagePosition = .imageLeading
            b.title = title(for: state)
        }
        runWatchdog(state: state, running: running, orphan: orphan)
        statusItem.menu = buildMenu(for: state, running: running, orphan: orphan)
    }

    /// Auto-recover a crashed / hung official app when the watchdog is enabled.
    private func runWatchdog(state: MinerState, running: Bool, orphan: Bool) {
        let now = Date()
        if running { lastSeenRunningAt = now }
        guard WatchdogSettings.enabled, !watchdogFlapped else { return }

        let recentlyUp = lastSeenRunningAt.map { now.timeIntervalSince($0) < 120 } ?? false
        let input = WatchdogInput(
            enabled: true,
            appRunning: running,
            orphanAlive: orphan,
            logStaleSeconds: state.lastLogTime.map { now.timeIntervalSince($0) },
            recentlyUp: recentlyUp,
            secondsSinceLastAction: lastWatchdogActionAt.map { now.timeIntervalSince($0) })
        let action = Watchdog.decide(input)
        guard action != .none else { return }

        // Flap guard: too many recoveries in a short window → stop and warn.
        recentWatchdogActions = recentWatchdogActions.filter { now.timeIntervalSince($0) < 900 }
        recentWatchdogActions.append(now)
        if recentWatchdogActions.count > 3 { watchdogFlapped = true; return }

        lastWatchdogActionAt = now
        switch action {
        case .relaunch: DispatchQueue.global().async { OfficialApp.reapOrphans(); OfficialApp.launch() }
        case .restart:  OfficialApp.restart()   // already dispatches to a background queue
        case .none:     break
        }
    }

    /// red = off · yellow = waiting for a lot (queued / transitional) · green = working.
    private func statusColor(for phase: Phase) -> NSColor {
        switch phase {
        case .working:                          return .systemGreen
        case .queued, .starting, .speedtest, .resetting: return .systemYellow
        case .off, .error:                      return .systemRed
        case .unknown:                          return .systemGray
        }
    }

    /// A small filled dot in menu-bar color (non-template so it keeps its color).
    private func dot(_ color: NSColor) -> NSImage {
        let d: CGFloat = 9
        let img = NSImage(size: NSSize(width: d, height: d))
        img.lockFocus()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: d, height: d)).fill()
        img.unlockFocus()
        img.isTemplate = false
        return img
    }

    private func read(capture: Bool) -> MinerState {
        switch LogReader.readTail() {
        case .missing, .empty:
            var s = MinerState(); s.phase = .off; return s
        case .ok(let text, _):
            if capture { UnknownCapture.capture(from: text) }
            return StateParser.parse(text: text)
        }
    }

    private func title(for s: MinerState) -> String {
        switch s.phase {
        case .off:      return "off"
        case .working:  return "working"
        case .queued:
            if let p = s.position { return "\(p)\(arrow(s.trendPerMin))" }
            return "queued"
        case .speedtest, .starting, .resetting: return "…"
        case .error:    return "⚠"
        case .unknown:  return "?"
        }
    }

    private func arrow(_ trend: Double?) -> String {
        guard let t = trend else { return "" }
        if t < -0.15 { return " ▼" }   // advancing toward the front (good)
        if t > 0.15  { return " ▲" }   // falling back (bad)
        return " ="
    }

    private func buildMenu(for s: MinerState, running: Bool, orphan: Bool) -> NSMenu {
        let m = NSMenu()
        func row(_ text: String) { m.addItem(withTitle: text, action: nil, keyEquivalent: "") }

        row("State:   \(s.phase.rawValue)")
        if let p = s.position {
            var line = "Queue:   \(p)"
            if let t = s.trendPerMin { line += String(format: "  (%+.1f/min)", t) }
            row(line)
        }
        if s.phase == .queued {
            if let eta = s.etaMinutesToFront { row("ETA:     \(fmtEta(eta))") }
            else { row("ETA:     — (queue not advancing)") }
        }
        if let up = s.uptime { row("Since:   \(fmtDuration(up))") }
        row("Work:    \(s.workLine ?? "idle (not assigned)")")
        if let ok = s.speedtestOk {
            row("Speedtest: \(ok ? "ok" : "fail (cosmetic, non-blocking)")")
        }
        if s.queueStateErrors > 0 || s.notFoundErrors > 0 {
            row("Backend: \(s.queueStateErrors)×503 queue_state, \(s.notFoundErrors)×404")
        }
        if let t = s.lastLogTime { row("Updated: \(fmtClock(t))") }

        // Official app lifecycle — we drive the official signed app, never bypass it.
        m.addItem(.separator())
        func action(_ title: String, _ sel: Selector, key: String = "") {
            let it = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            it.target = self; m.addItem(it)
        }
        let appStatus = NSMenuItem(title: "Official app: \(running ? "running" : "stopped")", action: nil, keyEquivalent: "")
        appStatus.image = dot(running ? .systemGreen : .systemRed)
        m.addItem(appStatus)
        if running {
            action("Restart official app", #selector(restartOfficial))
            action("Quit official app", #selector(quitOfficial))
        } else {
            action("Launch official app", #selector(launchOfficial))
            if orphan {
                action("⚠ Reap orphaned worker", #selector(reapOfficial))
            }
        }
        let wd = NSMenuItem(title: "Auto-restart on crash", action: #selector(toggleWatchdog), keyEquivalent: "")
        wd.target = self
        wd.image = dot(WatchdogSettings.enabled ? .systemGreen : .systemRed)
        m.addItem(wd)
        if watchdogFlapped {
            action("⚠ Watchdog stopped (flapping) — re-enable", #selector(reenableWatchdog))
        }
        if let ch = VersionWatch.change {
            m.addItem(NSMenuItem(title: "⚠ Official app \(ch.from) → \(ch.to) — verify parsing", action: nil, keyEquivalent: ""))
            action("Mark version verified", #selector(dismissVersionWarning))
        }

        m.addItem(.separator())
        let open = NSMenuItem(title: "Open log", action: #selector(openLog), keyEquivalent: "l")
        open.target = self; m.addItem(open)
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLoginQuick), keyEquivalent: "")
        login.target = self
        login.image = dot(PreferencesWindowController.launchAtLoginEnabled ? .systemGreen : .systemRed)
        m.addItem(login)
        let lid = NSMenuItem(title: "Keep awake, lid closed", action: #selector(toggleLidAwake), keyEquivalent: "")
        lid.target = self
        lid.image = dot(LidAwake.isEnabled ? .systemGreen : .systemRed)   // green = ON, red = OFF
        m.addItem(lid)
        let cap = NSMenuItem(title: "Capture unknown lines", action: #selector(toggleCapture), keyEquivalent: "")
        cap.target = self
        cap.image = dot(UnknownCapture.isEnabled ? .systemGreen : .systemRed)
        m.addItem(cap)
        if UnknownCapture.isEnabled { action("Open capture file", #selector(openCapture)) }
        let pref = NSMenuItem(title: "Preferences…", action: #selector(openPrefs), keyEquivalent: ",")
        pref.target = self; m.addItem(pref)
        if repoDir() != nil {
            let rb = NSMenuItem(title: "Rebuild & restart", action: #selector(rebuildAndRestart), keyEquivalent: "r")
            rb.target = self; m.addItem(rb)
        }
        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self; m.addItem(quit)
        return m
    }

    @objc private func openLog() {
        NSWorkspace.shared.open(URL(fileURLWithPath: LogReader.currentLogPath()))
    }

    @objc private func launchOfficial()  { OfficialApp.launch();  refreshSoon() }
    @objc private func quitOfficial()     { OfficialApp.quit();    refreshSoon() }
    @objc private func restartOfficial()  { OfficialApp.restart(); refreshSoon() }
    @objc private func reapOfficial()     { OfficialApp.reapOrphans(); refreshSoon() }

    /// Re-read + repaint shortly after a lifecycle action, once the app state settled.
    private func refreshSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.tick() }
    }

    @objc private func openPrefs() { prefs.show() }

    @objc private func toggleWatchdog() {
        WatchdogSettings.enabled.toggle()
        watchdogFlapped = false; recentWatchdogActions.removeAll()   // fresh flap window
        tick()
    }
    @objc private func reenableWatchdog() { watchdogFlapped = false; recentWatchdogActions.removeAll(); tick() }
    @objc private func dismissVersionWarning() { VersionWatch.acknowledge(); tick() }
    @objc private func toggleCapture() { UnknownCapture.isEnabled.toggle(); tick() }
    @objc private func openCapture() {
        NSWorkspace.shared.open(URL(fileURLWithPath: UnknownCapture.file))
    }

    /// Toggle lid-closed-awake. Warn about heat/battery before enabling.
    @objc private func toggleLidAwake() {
        if LidAwake.isEnabled {
            LidAwake.setEnabled(false); refreshSoon(); return
        }
        let a = NSAlert()
        a.messageText = "Keep the Mac awake with the lid closed?"
        a.informativeText = """
        This disables lid-close sleep on every power source (pmset disablesleep), so \
        the Mac keeps mining when you shut it — even on battery. It stays on until you \
        turn it back off here.

        ⚠️ While mining, a closed lid with no airflow (e.g. in a bag) can overheat the \
        Mac and drain the battery fast. Only use it somewhere open and ventilated, \
        ideally on power.
        """
        a.alertStyle = .warning
        a.addButton(withTitle: "Enable")
        a.addButton(withTitle: "Cancel")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        if !LidAwake.setEnabled(true) {
            let e = NSAlert(); e.messageText = "Could not enable (auth cancelled or failed)"
            e.alertStyle = .warning; e.runModal()
        }
        refreshSoon()
    }

    /// Quick toggle straight from the menu checkbox (mirrors the panel switch).
    @objc private func toggleLoginQuick() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() }
            else { try service.register() }
        } catch {
            let a = NSAlert(); a.messageText = "Failed to change launch-at-login setting"
            a.informativeText = error.localizedDescription; a.alertStyle = .warning; a.runModal()
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Rebuild & restart

    /// Repo directory holding `build.sh`, next to our (symlink-resolved) bundle.
    /// nil when the app was copied away from its source tree.
    private func repoDir() -> String? {
        let dir = Bundle.main.bundleURL.resolvingSymlinksInPath().deletingLastPathComponent()
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent("build.sh").path) ? dir.path : nil
    }

    @objc private func rebuildAndRestart() {
        guard let repo = repoDir() else { return }
        DispatchQueue.global().async {
            let result = self.runBuild(in: repo)
            DispatchQueue.main.async {
                guard result.status == 0 else {
                    let a = NSAlert(); a.messageText = "Rebuild failed"
                    a.informativeText = String(result.out.suffix(700)); a.alertStyle = .warning; a.runModal()
                    return
                }
                // Relaunch the freshly built bundle after we exit.
                let bundle = Bundle.main.bundleURL.resolvingSymlinksInPath().path
                let relaunch = Process()
                relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
                relaunch.arguments = ["-c", "sleep 1; open \"\(bundle)\""]
                try? relaunch.run()
                NSApp.terminate(nil)
            }
        }
    }

    private func runBuild(in repo: String) -> (status: Int32, out: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["build.sh"]
        p.currentDirectoryURL = URL(fileURLWithPath: repo)
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        do {
            try p.run()
            // Drain the pipe BEFORE waiting: a build that outputs more than the
            // pipe buffer would otherwise block writing while we wait → deadlock.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return (p.terminationStatus, String(decoding: data, as: UTF8.self))
        } catch { return (-1, "\(error)") }
    }

    private func fmtDuration(_ t: TimeInterval) -> String {
        let s = Int(t); return String(format: "%02d:%02d:%02d", s/3600, (s%3600)/60, s%60)
    }
    private func fmtClock(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: d)
    }

    /// "~8h40m  (→ Sun 6 Jul 03:20)" — rough duration + absolute target time.
    private func fmtEta(_ minutes: Double) -> String {
        let h = Int(minutes) / 60, m = Int(minutes) % 60
        let dur = h > 0 ? "\(h)h\(String(format: "%02d", m))m" : "\(m)m"
        let target = Date().addingTimeInterval(minutes * 60)
        let f = DateFormatter()
        f.dateFormat = Calendar.current.isDateInToday(target) ? "HH:mm" : "EEE d MMM HH:mm"
        return "~\(dur)  (→ \(f.string(from: target)))"
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // menu bar only, no Dock icon
let delegate = MenuBarApp()
app.delegate = delegate
app.run()
