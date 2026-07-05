import AppKit

/// Menu bar app: reads the IOTA T@H CLI log every few seconds and renders the
/// real queue position / state / work status the official UI fails to show.
final class MenuBarApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private let refresh: TimeInterval = 5

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
        statusItem.button?.title = title(for: state)
        statusItem.menu = buildMenu(for: state)
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
        case .off:      return "⛏ off"
        case .working:  return "⛏ ▶︎"
        case .queued:
            if let p = s.position { return "⛏ \(p)\(arrow(s.trendPerMin))" }
            return "⛏ queued"
        case .speedtest, .starting, .resetting: return "⛏ …"
        case .error:    return "⛏ ⚠"
        case .unknown:  return "⛏ ?"
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
        if s.phase == .off { row("(official app not running / log stale)") }

        m.addItem(.separator())
        let open = NSMenuItem(title: "Open log", action: #selector(openLog), keyEquivalent: "l")
        open.target = self; m.addItem(open)
        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self; m.addItem(quit)
        return m
    }

    @objc private func openLog() {
        NSWorkspace.shared.open(URL(fileURLWithPath: LogReader.todayLogPath()))
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
