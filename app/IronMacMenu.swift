import AppKit
import Foundation
import LocalAuthentication

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

    struct VaultWalletInfo {
        let alias: String
        let address: String
        let chain: String
        let isKeystore: Bool
        let filePath: String
        let isPermanent: Bool
        let storage: String
    }

    struct VaultTelemetry {
        let isRamDiskActive: Bool
        let volumeName: String
        let mountPath: String
        let hasValidTicket: Bool
        let wallets: [VaultWalletInfo]
        let permanentCount: Int
        let ramCount: Int
    }

    func detectVaultTelemetry() -> VaultTelemetry {
        let fm = FileManager.default
        var wallets: [VaultWalletInfo] = []
        var seenAliases = Set<String>()
        var permCount = 0
        var ramCount = 0

        // 1. Scan Permanent Keystores (~/.ironmac/keystores/)
        let home = fm.homeDirectoryForCurrentUser.path
        let permDir = "\(home)/.ironmac/keystores"
        if let permFiles = try? fm.contentsOfDirectory(atPath: permDir) {
            for f in permFiles where f.hasSuffix(".json") && !f.hasSuffix(".keystore.json") {
                let fullPath = "\(permDir)/\(f)"
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                let alias = (json["alias"] as? String) ?? (f as NSString).deletingPathExtension
                let address = (json["address"] as? String) ?? "0x..."
                let chain = (json["chain"] as? String) ?? "base"
                let isKeystore = json["keystore_file"] != nil
                seenAliases.insert(alias)
                permCount += 1
                wallets.append(VaultWalletInfo(
                    alias: alias,
                    address: address,
                    chain: chain,
                    isKeystore: isKeystore,
                    filePath: fullPath,
                    isPermanent: true,
                    storage: "Permanent Keystore (~/.ironmac/keystores/)"
                ))
            }
        }

        // 2. Scan Volatile RAMDisk
        let vols = (try? fm.contentsOfDirectory(atPath: "/Volumes")) ?? []
        let candidates = vols.filter { $0.hasPrefix("IronVault") }.compactMap { vol -> (name: String, path: String, mtime: Date, keyCount: Int)? in
            let path = "/Volumes/\(vol)"
            let keysPath = "\(path)/keys"
            let keyCount = (try? fm.contentsOfDirectory(atPath: keysPath))?.filter { $0.hasSuffix(".json") && !$0.hasSuffix(".keystore.json") }.count ?? 0
            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let mdate = attrs[.modificationDate] as? Date else { return nil }
            return (vol, path, mdate, keyCount)
        }.sorted { (a, b) -> Bool in
            if a.keyCount > 0 && b.keyCount == 0 { return true }
            if a.keyCount == 0 && b.keyCount > 0 { return false }
            return a.mtime > b.mtime
        }

        let isRamActive = !candidates.isEmpty
        let best = candidates.first
        let ironVol = best?.name ?? ""
        let vaultPath = best?.path ?? ""
        var hasTicket = false

        if isRamActive {
            let ticketPath = "\(vaultPath)/.auth_ticket"
            if fm.fileExists(atPath: ticketPath),
               let content = try? String(contentsOfFile: ticketPath, encoding: .utf8),
               let timestamp = Double(content.trimmingCharacters(in: .whitespacesAndNewlines)) {
                let age = Date().timeIntervalSince1970 - timestamp
                hasTicket = age >= 0 && age < 600
            }

            let keysDir = "\(vaultPath)/keys"
            if let files = try? fm.contentsOfDirectory(atPath: keysDir) {
                for f in files where f.hasSuffix(".json") && !f.hasSuffix(".keystore.json") {
                    let fullPath = "\(keysDir)/\(f)"
                    guard let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                    let alias = (json["alias"] as? String) ?? (f as NSString).deletingPathExtension
                    if !seenAliases.contains(alias) {
                        seenAliases.insert(alias)
                        ramCount += 1
                        let address = (json["address"] as? String) ?? "0x..."
                        let chain = (json["chain"] as? String) ?? "base"
                        let isKeystore = json["keystore_file"] != nil
                        wallets.append(VaultWalletInfo(
                            alias: alias,
                            address: address,
                            chain: chain,
                            isKeystore: isKeystore,
                            filePath: fullPath,
                            isPermanent: false,
                            storage: "RAMDisk (Volatile Memory)"
                        ))
                    }
                }
            }
        }

        return VaultTelemetry(
            isRamDiskActive: isRamActive,
            volumeName: ironVol,
            mountPath: vaultPath,
            hasValidTicket: hasTicket,
            wallets: wallets,
            permanentCount: permCount,
            ramCount: ramCount
        )
    }

    @objc func copyWalletAddress(_ sender: NSMenuItem) {
        if let addr = sender.representedObject as? String {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(addr, forType: .string)
            sendDesktopAlert(title: "Address Copied", message: "Public address copied: \(addr)")
        }
    }

    @objc func lockSessionTicket() {
        let vaultInfo = detectVaultTelemetry()
        if vaultInfo.isRamDiskActive {
            let ticketPath = "\(vaultInfo.mountPath)/.auth_ticket"
            try? FileManager.default.removeItem(atPath: ticketPath)
            sendDesktopAlert(title: "IronMac Session Locked", message: "Touch ID grace period revoked. Next action requires authentication.")
            buildMenu()
        }
    }

    @objc func revealWalletKeyFromMenu(_ sender: NSMenuItem) {
        guard let w = sender.representedObject as? VaultWalletInfo else { return }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            sendDesktopAlert(title: "Authentication Failed", message: "Biometric authentication unavailable.")
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authorize copying private key for '\(w.alias)' to clipboard") { success, _ in
            DispatchQueue.main.async {
                if success {
                    self.copyKeyToClipboardForWallet(w)
                } else {
                    self.sendDesktopAlert(title: "Authentication Cancelled", message: "Touch ID verification was not completed.")
                }
            }
        }
    }

    func copyKeyToClipboardForWallet(_ w: VaultWalletInfo) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: w.filePath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            sendDesktopAlert(title: "Key Retrieval Failed", message: "Could not read wallet metadata.")
            return
        }

        var privKey = json["private_key"] as? String ?? ""

        if privKey.isEmpty && w.isKeystore {
            // Retrieve password from Apple Keychain
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
            process.arguments = ["find-generic-password", "-a", w.alias, "-s", "ironmac.vault.keystore", "-w"]
            let pipe = Pipe()
            process.standardOutput = pipe
            try? process.run()
            process.waitUntilExit()
            let outData = pipe.fileHandleForReading.readDataToEndOfFile()
            let pass = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if !pass.isEmpty {
                let fm = FileManager.default
                let nodeBin = fm.fileExists(atPath: "/opt/homebrew/bin/node") ? "/opt/homebrew/bin/node" : (fm.fileExists(atPath: "/usr/local/bin/node") ? "/usr/local/bin/node" : "node")
                let ksFilePath = w.filePath.replacingOccurrences(of: ".json", with: ".keystore.json")

                let nodeProcess = Process()
                nodeProcess.executableURL = URL(fileURLWithPath: nodeBin)
                let script = """
                const fs = require('fs');
                const crypto = require('crypto');
                try {
                  const ks = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
                  const pass = process.argv[2];
                  const c = ks.crypto || ks.Crypto;
                  const salt = Buffer.from(c.kdfparams.salt, 'hex');
                  const n = c.kdfparams.n || 8192;
                  const r = c.kdfparams.r || 8;
                  const p = c.kdfparams.p || 1;
                  const dklen = c.kdfparams.dklen || 32;
                  const derivedKey = crypto.scryptSync(Buffer.from(pass, 'utf-8'), salt, dklen, { N: n, r, p, maxmem: 128 * 1024 * 1024 });
                  const cipherKey = derivedKey.subarray(0, 16);
                  const iv = Buffer.from(c.cipherparams.iv, 'hex');
                  const decipher = crypto.createDecipheriv('aes-128-ctr', cipherKey, iv);
                  const ciphertext = Buffer.from(c.ciphertext, 'hex');
                  const privKey = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
                  process.stdout.write('0x' + privKey.toString('hex'));
                } catch(e) { process.exit(1); }
                """
                nodeProcess.arguments = ["-e", script, ksFilePath, pass]
                let nPipe = Pipe()
                nodeProcess.standardOutput = nPipe
                try? nodeProcess.run()
                nodeProcess.waitUntilExit()

                if nodeProcess.terminationStatus == 0 {
                    let keyData = nPipe.fileHandleForReading.readDataToEndOfFile()
                    privKey = String(data: keyData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                }
            }
        }

        if !privKey.isEmpty && privKey.starts(with: "0x") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(privKey, forType: .string)
            sendDesktopAlert(
                title: "⚡ Private Key Copied",
                message: "Private key for '\(w.alias)' copied to clipboard directly. Screen display suppressed for security (anti-shoulder surfing)."
            )
        } else {
            sendDesktopAlert(
                title: "Key Decryption Failed",
                message: "Unable to decrypt private key for '\(w.alias)'. Ensure Apple Keychain permission is granted."
            )
        }
    }

    func buildMenu() {
        menu.removeAllItems()

        let airgapped = cachedAirgapped
        let trapRunning = cachedTrapRunning
        let clipRunning = cachedClipRunning

        // 1. Header
        let header = NSMenuItem(title: "⚡ IronMac Fortress v0.6.4", action: nil, keyEquivalent: "")
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

        // 2.5. Keystores & Vault Telemetry
        let vaultInfo = detectVaultTelemetry()
        let totalWallets = vaultInfo.wallets.count

        if totalWallets > 0 {
            var summaryParts: [String] = []
            if vaultInfo.permanentCount > 0 { summaryParts.append("\(vaultInfo.permanentCount) Permanent") }
            if vaultInfo.ramCount > 0 { summaryParts.append("\(vaultInfo.ramCount) RAMDisk") }
            let parentItem = NSMenuItem(title: "  🔑 Vault Wallets (\(summaryParts.joined(separator: ", ")))", action: nil, keyEquivalent: "")
            let walletsMenu = NSMenu()
            parentItem.submenu = walletsMenu

            for w in vaultInfo.wallets {
                let shortAddr = w.address.count > 12 ? "\(w.address.prefix(6))...\(w.address.suffix(4))" : w.address
                let typeIcon = w.isPermanent ? "🔐" : "⚡"
                let wItem = NSMenuItem(title: "• \(w.alias) [\(w.chain.uppercased())] \(typeIcon): \(shortAddr)", action: nil, keyEquivalent: "")
                let wSub = NSMenu()
                wItem.submenu = wSub

                let storageItem = NSMenuItem(title: "  Storage: \(w.storage)", action: nil, keyEquivalent: "")
                storageItem.isEnabled = false
                wSub.addItem(storageItem)

                let copyAddrItem = NSMenuItem(title: "📋 Copy Address (\(shortAddr))", action: #selector(copyWalletAddress(_:)), keyEquivalent: "")
                copyAddrItem.representedObject = w.address
                copyAddrItem.target = self
                wSub.addItem(copyAddrItem)

                let revealItem = NSMenuItem(title: "📋 Copy Private Key (Touch ID Required)", action: #selector(revealWalletKeyFromMenu(_:)), keyEquivalent: "")
                revealItem.representedObject = w
                revealItem.target = self
                wSub.addItem(revealItem)

                walletsMenu.addItem(wItem)
            }
            menu.addItem(parentItem)
        } else {
            let emptyItem = NSMenuItem(title: "  🔑 Vault Wallets: None configured", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        }

        if vaultInfo.isRamDiskActive {
            let vaultItem = NSMenuItem(title: "● RAMDisk Vault: ACTIVE (\(vaultInfo.volumeName))", action: nil, keyEquivalent: "")
            vaultItem.isEnabled = false
            menu.addItem(vaultItem)

            if vaultInfo.hasValidTicket {
                let ticketItem = NSMenuItem(title: "  ⚡ Touch ID Grace Period: ACTIVE (Unlocked)", action: nil, keyEquivalent: "")
                ticketItem.isEnabled = false
                menu.addItem(ticketItem)

                let lockItem = NSMenuItem(title: "  ↳ 🔒 Lock Session Ticket", action: #selector(lockSessionTicket), keyEquivalent: "")
                lockItem.target = self
                menu.addItem(lockItem)
            } else {
                let ticketItem = NSMenuItem(title: "  🔒 Session Ticket: LOCKED (Touch ID Required)", action: nil, keyEquivalent: "")
                ticketItem.isEnabled = false
                menu.addItem(ticketItem)
            }
        } else {
            let vaultItem = NSMenuItem(title: "○ RAMDisk Vault: INACTIVE (Permanent Keystores Active)", action: nil, keyEquivalent: "")
            vaultItem.isEnabled = false
            menu.addItem(vaultItem)
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
