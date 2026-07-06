import Foundation

/// App-side on/off flag for the auto-restart watchdog (the decision logic lives
/// in the core `Watchdog`). Persisted across launches.
enum WatchdogSettings {
    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: "watchdog.enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "watchdog.enabled") }
    }
}
