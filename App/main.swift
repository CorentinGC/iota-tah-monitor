import AppKit
import ServiceManagement

/// Menu bar app: reads the IOTA T@H CLI log every few seconds and renders the
/// real queue position / state / work status the official UI fails to show.
final class MenuBarApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private let refresh: TimeInterval = 5
    private let prefs = PreferencesWindowController()

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⛏ …"
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: refresh, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        let state = read()
        if let b = statusItem.button {
            b.image = dot(statusColor(for: state.phase))
            b.imagePosition = .imageLeading
            b.title = title(for: state)
        }
        statusItem.menu = buildMenu(for: state)
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

    private func read() -> MinerState {
        switch LogReader.readTail() {
        case .missing, .empty:
            var s = MinerState(); s.phase = .off; return s
        case .ok(let text, _):
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
        if t < -0.5 { return " ▼" }   // advancing toward the front (good)
        if t > 0.5  { return " ▲" }   // falling back (bad)
        return " ="
    }

    private func buildMenu(for s: MinerState) -> NSMenu {
        let m = NSMenu()
        func row(_ text: String) { m.addItem(withTitle: text, action: nil, keyEquivalent: "") }

        row("State:   \(s.phase.rawValue)")
        if let p = s.position {
            var line = "Queue:   \(p)"
            if let t = s.trendPerMin { line += String(format: "  (%+.1f/min)", t) }
            row(line)
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
        if OfficialApp.isRunning {
            row("Official app:  running")
            action("Restart official app", #selector(restartOfficial))
            action("Quit official app", #selector(quitOfficial))
        } else {
            row("Official app:  stopped")
            action("Launch official app", #selector(launchOfficial))
            if OfficialApp.orphanWorkerAlive() {
                action("⚠ Reap orphaned worker", #selector(reapOfficial))
            }
        }

        m.addItem(.separator())
        let open = NSMenuItem(title: "Open log", action: #selector(openLog), keyEquivalent: "l")
        open.target = self; m.addItem(open)
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLoginQuick), keyEquivalent: "")
        login.target = self
        login.state = PreferencesWindowController.launchAtLoginEnabled ? .on : .off
        m.addItem(login)
        let pref = NSMenuItem(title: "Preferences…", action: #selector(openPrefs), keyEquivalent: ",")
        pref.target = self; m.addItem(pref)
        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self; m.addItem(quit)
        return m
    }

    @objc private func openLog() {
        NSWorkspace.shared.open(URL(fileURLWithPath: LogReader.todayLogPath()))
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

    private func fmtDuration(_ t: TimeInterval) -> String {
        let s = Int(t); return String(format: "%02d:%02d:%02d", s/3600, (s%3600)/60, s%60)
    }
    private func fmtClock(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: d)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // menu bar only, no Dock icon
let delegate = MenuBarApp()
app.delegate = delegate
app.run()
