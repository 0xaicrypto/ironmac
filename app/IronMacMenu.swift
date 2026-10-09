import AppKit
import Foundation

class IronMacMenuDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    let menu = NSMenu()

    // Cached telemetry states for zero-lag instant UI responsiveness
    private var cachedAirgapped: Bool = false
    private var cachedTrapRunning: Bool = false
    private var cachedClipRunning: Bool = false
    private var isRefreshing: Bool = false

    // Dynamically detect Wi-Fi interface once
    lazy var wifiDevice: String = {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-listallhardwareports"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let lines = output.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            if line.contains("Wi-Fi") || line.contains("AirPort") {
                if i + 1 < lines.count {
                    let next = lines[i + 1]
                    if let dev = next.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespaces) {
                        return dev
                    }
                }
            }
        }
        return "en0"
    }()

    // Resolve ironmac binary location
    var ironmacBin: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/ironmac",
            "/opt/homebrew/bin/ironmac",
            "/usr/local/bin/ironmac",
            "\(home)/.ironmac/bin/ironmac",
            Bundle.main.bundlePath + "/Contents/MacOS/ironmac"
        ]
        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return "ironmac"
    }

    // Custom Vector Fortress Shield Icon (No Emoji - Pure Native macOS Vector)
    func createShieldIcon(airgapped: Bool, armed: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // Outer Fortress Shield Path
            let shield = NSBezierPath()
            shield.move(to: NSPoint(x: 9.0, y: 16.5))
            shield.line(to: NSPoint(x: 15.5, y: 14.2))
            shield.curve(to: NSPoint(x: 15.5, y: 8.5), controlPoint1: NSPoint(x: 15.5, y: 14.2), controlPoint2: NSPoint(x: 15.5, y: 11.0))
            shield.curve(to: NSPoint(x: 9.0, y: 1.5), controlPoint1: NSPoint(x: 15.5, y: 4.8), controlPoint2: NSPoint(x: 12.0, y: 2.8))
            shield.curve(to: NSPoint(x: 2.5, y: 8.5), controlPoint1: NSPoint(x: 6.0, y: 2.8), controlPoint2: NSPoint(x: 2.5, y: 4.8))
            shield.curve(to: NSPoint(x: 2.5, y: 14.2), controlPoint1: NSPoint(x: 2.5, y: 11.0), controlPoint2: NSPoint(x: 2.5, y: 14.2))
            shield.close()

            shield.lineWidth = 1.3
            shield.lineJoinStyle = .round
            NSColor.black.setStroke()
            shield.stroke()

            if airgapped {
                // Lightning Bolt for Hardware Air-Gap Active
                let bolt = NSBezierPath()
                bolt.move(to: NSPoint(x: 9.6, y: 13.8))
                bolt.line(to: NSPoint(x: 6.8, y: 9.2))
                bolt.line(to: NSPoint(x: 9.0, y: 9.2))
                bolt.line(to: NSPoint(x: 8.4, y: 4.8))
                bolt.line(to: NSPoint(x: 11.8, y: 9.2))
                bolt.line(to: NSPoint(x: 9.6, y: 9.2))
                bolt.close()
                NSColor.black.setFill()
                bolt.fill()
            } else if armed {
                // Verification Checkmark for Armed Defenses
                let check = NSBezierPath()
                check.move(to: NSPoint(x: 5.8, y: 8.8))
                check.line(to: NSPoint(x: 8.2, y: 6.2))
                check.line(to: NSPoint(x: 12.2, y: 11.5))
                check.lineWidth = 1.4
                check.lineCapStyle = .round
                check.lineJoinStyle = .round
                NSColor.black.setStroke()
                check.stroke()
            } else {
                // Subtle Center Dot for Partial Status
                let dot = NSBezierPath(ovalIn: NSRect(x: 7.6, y: 7.6, width: 2.8, height: 2.8))
                NSColor.black.setFill()
                dot.fill()
            }

            return true
        }
        image.isTemplate = true
        return image
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = createShieldIcon(airgapped: false, armed: true)
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = "IronMac Web3 Fortress Workstation"
        }
        menu.delegate = self
        statusItem.menu = menu
        buildMenu()

        // Initial background telemetry refresh
        refreshStatusAsync()

        // Background timer to refresh telemetry every 4 seconds asynchronously
        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.refreshStatusAsync()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        buildMenu()
    }

    func refreshStatusAsync() {
        guard !isRefreshing else { return }
        isRefreshing = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let airgapped = self.checkAirgapActive()
            let trapRunning = self.checkProcessRunning("trap_sentry.py")
            let clipRunning = self.checkProcessRunning("clip_guard.py")

            DispatchQueue.main.async {
                self.cachedAirgapped = airgapped
                self.cachedTrapRunning = trapRunning
                self.cachedClipRunning = clipRunning
                self.isRefreshing = false
                self.updateStatusButton()
            }
        }
    }

    func updateStatusButton() {
        guard let button = statusItem?.button else { return }
        let allArmed = cachedTrapRunning && cachedClipRunning

        button.image = createShieldIcon(airgapped: cachedAirgapped, armed: allArmed)
        button.title = ""
        button.imagePosition = .imageOnly

        if cachedAirgapped {
            button.toolTip = "IronMac: Hardware Air-Gap ACTIVE (Wi-Fi OFF)"
        } else if allArmed {
            button.toolTip = "IronMac: Defenses ARMED"
        } else {
            button.toolTip = "IronMac: Defenses PARTIAL"
        }
    }

    func checkAirgapActive() -> Bool {
        let dev = wifiDevice
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-getairportpower", dev]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return !output.contains("On")
    }

    func checkProcessRunning(_ name: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", name]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    @objc func toggleAirgap() {
        let currentlyAirgapped = cachedAirgapped
        let dev = wifiDevice
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-setairportpower", dev, currentlyAirgapped ? "on" : "off"]
        try? process.run()
        process.waitUntilExit()
        refreshStatusAsync()
    }

    @objc func openVaultConsole() {
        let bin = ironmacBin
        let script = """
        tell application "Terminal"
            activate
            do script "\(bin) console"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    @objc func openVaultBrowser() {
        let bin = ironmacBin
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "\(bin) vault-browser >/dev/null 2>&1 &"]
        try? process.run()
    }

    @objc func clearClipboard() {
        NSPasteboard.general.clearContents()
        sendDesktopAlert(title: "IronMac Pasteboard Purged", message: "✓ Clipboard memory successfully wiped to /dev/null.")
    }

    @objc func triggerPanic() {
        let alert = NSAlert()
        alert.messageText = "🚨 Trigger Emergency Panic Air-Gap?"
        alert.informativeText = "In <1s, this will:\n• Power off Wi-Fi hardware (en0)\n• Purge pasteboard memory\n• Terminate browsers and chat apps\n• Lock the screen"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "TRIGGER PANIC NOW")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let bin = ironmacBin
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", "\(bin) panic trigger \"Triggered via MenuBar Companion App\""]
            try? process.run()
            refreshStatusAsync()
        }
    }

    @objc func runAudit() {
        let bin = ironmacBin
        let script = """
        tell application "Terminal"
            activate
            do script "\(bin) audit"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    @objc func startDefenses() {
        let bin = ironmacBin
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "\(bin) trap start; \(bin) clip-guard start"]
        try? process.run()
        process.waitUntilExit()
        refreshStatusAsync()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func sendDesktopAlert(title: String, message: String) {
        let script = "display notification \"\(message)\" with title \"\(title)\""
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    func buildMenu() {
        menu.removeAllItems()

        let airgapped = cachedAirgapped
        let trapRunning = cachedTrapRunning
        let clipRunning = cachedClipRunning

        // 1. Header
        let header = NSMenuItem(title: "⚡ IronMac Fortress v0.6.3", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        // 2. Status overview
        let allArmed = trapRunning && clipRunning
        let statusTitle = allArmed ? "● Active Defenses: ARMED" : "○ Active Defenses: PARTIAL"
        let statusOverviewItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusOverviewItem.isEnabled = false
        menu.addItem(statusOverviewItem)

        if !allArmed {
            let armItem = NSMenuItem(title: "  ↳ Click to Arm Trap & ClipGuard", action: #selector(startDefenses), keyEquivalent: "")
            armItem.target = self
            menu.addItem(armItem)
        }

        menu.addItem(NSMenuItem.separator())

        // 3. Workstation Tools
        let consoleItem = NSMenuItem(title: "⚡ Launch IronVault Console", action: #selector(openVaultConsole), keyEquivalent: "c")
        consoleItem.target = self
        menu.addItem(consoleItem)

        let browserItem = NSMenuItem(title: "🌐 Launch Vault Browser", action: #selector(openVaultBrowser), keyEquivalent: "b")
        browserItem.target = self
        menu.addItem(browserItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Hardware Air-Gap Switch
        let airgapTitle = airgapped ? "📶 Hardware Air-Gap: ACTIVE (Wi-Fi OFF)" : "📶 Hardware Air-Gap: ONLINE (Wi-Fi ON)"
        let airgapItem = NSMenuItem(title: airgapTitle, action: #selector(toggleAirgap), keyEquivalent: "a")
        airgapItem.target = self
        menu.addItem(airgapItem)

        let clipItem = NSMenuItem(title: "📋 Purge Pasteboard Memory", action: #selector(clearClipboard), keyEquivalent: "k")
        clipItem.target = self
        menu.addItem(clipItem)

        let auditItem = NSMenuItem(title: "🔍 Run Security Health Audit...", action: #selector(runAudit), keyEquivalent: "")
        auditItem.target = self
        menu.addItem(auditItem)

        menu.addItem(NSMenuItem.separator())

        // 5. Emergency Threat Panic
        let panicItem = NSMenuItem(title: "🚨 EMERGENCY AIR-GAP PANIC", action: #selector(triggerPanic), keyEquivalent: "p")
        panicItem.target = self
        menu.addItem(panicItem)

        menu.addItem(NSMenuItem.separator())

        // 6. Quit
        let quitItem = NSMenuItem(title: "Quit IronMac Menu", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }
}

let app = NSApplication.shared
let delegate = IronMacMenuDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
