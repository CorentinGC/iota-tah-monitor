import Foundation

/// Pure decision for the optional auto-restart watchdog. All side effects (reap,
/// launch, restart) live in the app; this only decides what should happen from
/// observable facts, so it can be unit-tested.
public enum WatchdogAction: Equatable {
    case none
    case relaunch   // app crashed (shell gone, workers orphaned) → reap + launch
    case restart    // app alive but worker hung (log stalled) → quit + reap + launch
}

public struct WatchdogInput {
    public var enabled: Bool
    public var appRunning: Bool
    public var orphanAlive: Bool
    public var logStaleSeconds: Double?          // age of the last log line; nil if unknown
    public var recentlyUp: Bool                  // app was seen running within a recent window
    public var secondsSinceLastAction: Double?   // nil if the watchdog never acted

    public init(enabled: Bool, appRunning: Bool, orphanAlive: Bool,
                logStaleSeconds: Double?, recentlyUp: Bool, secondsSinceLastAction: Double?) {
        self.enabled = enabled; self.appRunning = appRunning; self.orphanAlive = orphanAlive
        self.logStaleSeconds = logStaleSeconds; self.recentlyUp = recentlyUp
        self.secondsSinceLastAction = secondsSinceLastAction
    }
}

public enum Watchdog {
    /// Decide the recovery action. Conservative on purpose: never launches an app
    /// the user deliberately keeps off (requires it to have been up recently), and
    /// throttles via `minInterval` so a slow boot isn't mistaken for a new crash.
    public static func decide(_ i: WatchdogInput,
                              staleThreshold: Double = 300,
                              minInterval: Double = 180) -> WatchdogAction {
        guard i.enabled, i.recentlyUp else { return .none }
        if let since = i.secondsSinceLastAction, since < minInterval { return .none }
        if !i.appRunning {
            return i.orphanAlive ? .relaunch : .none      // down + orphans = crash; clean quit = leave it
        }
        if let stale = i.logStaleSeconds, stale > staleThreshold { return .restart }  // zombie worker
        return .none
    }
}
