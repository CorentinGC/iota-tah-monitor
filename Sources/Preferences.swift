import AppKit
import ServiceManagement

/// Small config panel: toggle "launch at login" via SMAppService (macOS 13+).
/// No LaunchAgent plist, no helper bundle — registers the main app bundle itself.
final class PreferencesWindowController: NSObject {
    private var window: NSWindow?
    private var loginSwitch: NSButton!
    private var statusLabel: NSTextField!

    /// Current login-item state of this app bundle.
    static var launchAtLoginEnabled: Bool { SMAppService.mainApp.status == .enabled }

    func show() {
        if window == nil { build() }
        syncFromSystem()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        w.title = "IOTA Monitor — Préférences"
        w.isReleasedWhenClosed = false

        let content = NSView(frame: w.contentView!.bounds)
        content.autoresizingMask = [.width, .height]

        let title = NSTextField(labelWithString: "Démarrage")
        title.font = .boldSystemFont(ofSize: 13)
        title.frame = NSRect(x: 20, y: 108, width: 320, height: 20)
        content.addSubview(title)

        loginSwitch = NSButton(checkboxWithTitle: "Lancer au démarrage de session",
                               target: self, action: #selector(toggleLogin))
        loginSwitch.frame = NSRect(x: 20, y: 78, width: 320, height: 22)
        content.addSubview(loginSwitch)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.frame = NSRect(x: 20, y: 20, width: 320, height: 40)
        statusLabel.maximumNumberOfLines = 3
        content.addSubview(statusLabel)

        w.contentView = content
        window = w
    }

    private func syncFromSystem() {
        let status = SMAppService.mainApp.status
        loginSwitch.state = (status == .enabled) ? .on : .off
        switch status {
        case .enabled:
            statusLabel.stringValue = "Actif : l'app se lancera à l'ouverture de session."
        case .requiresApproval:
            statusLabel.stringValue = "En attente d'approbation dans Réglages Système › Général › Ouverture."
        case .notRegistered, .notFound:
            statusLabel.stringValue = "Inactif."
        @unknown default:
            statusLabel.stringValue = ""
        }
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if loginSwitch.state == .on {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            // Revert the checkbox and explain — never leave UI out of sync.
            let alert = NSAlert()
            alert.messageText = "Impossible de modifier le démarrage au login"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
        syncFromSystem()
    }
}
