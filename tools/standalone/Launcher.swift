import AppKit

final class Launcher: NSObject, NSApplicationDelegate {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 355), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
    let status = NSTextField(wrappingLabelWithString: "Checking imported game files…")
    let detail = NSTextField(wrappingLabelWithString: "")
    var pcButton: NSButton!
    var genesisButton: NSButton!
    var playButton: NSButton!
    var running: Process?
    var busy = false
    var pcReady = false
    let runtime = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/runtime/AbramsRuntime/AbramsRuntime")
    var setupArgs: [String] {
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--data-home"), index+1 < args.count { return ["--data-home", args[index+1]] }
        return []
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu()
        let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit Abrams", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = menu
        window.title = "Abrams"
        window.isReleasedWhenClosed = false
        let view = window.contentView!
        let title = NSTextField(labelWithString: "M1 Abrams Battle Tank")
        title.font = .boldSystemFont(ofSize: 25); title.frame = NSRect(x: 28, y: 289, width: 564, height: 34); view.addSubview(title)
        let intro = NSTextField(wrappingLabelWithString: "Original PC simulation, remastered presentation.\nImport your PC game folder to play. A supported Genesis ROM is optional.")
        intro.frame = NSRect(x: 28, y: 230, width: 564, height: 48); view.addSubview(intro)
        status.font = .boldSystemFont(ofSize: 14); status.frame = NSRect(x: 28, y: 180, width: 564, height: 42); view.addSubview(status)
        detail.font = .systemFont(ofSize: 12); detail.textColor = .secondaryLabelColor
        detail.frame = NSRect(x: 28, y: 86, width: 564, height: 85); view.addSubview(detail)
        pcButton = NSButton(title: "Choose PC folder…", target: self, action: #selector(choosePC)); pcButton.frame = NSRect(x: 24, y: 30, width: 172, height: 34); view.addSubview(pcButton)
        genesisButton = NSButton(title: "Add Genesis ROM…", target: self, action: #selector(chooseGenesis)); genesisButton.frame = NSRect(x: 201, y: 30, width: 181, height: 34); view.addSubview(genesisButton)
        playButton = NSButton(title: "Play", target: self, action: #selector(play)); playButton.frame = NSRect(x: 478, y: 30, width: 116, height: 34); playButton.keyEquivalent = "\r"; view.addSubview(playButton)
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        refresh()
    }
    func controls(_ enabled: Bool) { pcButton.isEnabled = enabled; genesisButton.isEnabled = enabled; playButton.isEnabled = enabled }
    func refresh(_ result: [String: Any]? = nil) {
        guard let result else { call(["--status"], completion: { self.refresh($0) }); return }
        let pc = result["pc_installed"] as? Bool ?? false
        let genesis = result["genesis_enabled"] as? Bool ?? false
        pcReady = pc
        controls(true); genesisButton.isEnabled = pc; playButton.isEnabled = pc
        status.stringValue = pc ? "Ready to play · \(genesis ? "Genesis presentation enabled" : "PC-only presentation")" : "Original PC game required"
        detail.stringValue = (result["problem"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? (pc ? "Your originals and save states stay outside the application.\n\(result["data_home"] as? String ?? "")\nLocal private alpha. Modern graphics are deferred." : "Select the extracted folder containing ABRAMS.COM and SIM.EXE. All supported files are checked before import. Your source files are never changed.\nGenesis alone cannot run the PC simulation.")
    }
    func call(_ arguments: [String], completion: @escaping ([String: Any]) -> Void) {
        if busy { return }; busy = true; controls(false)
        let process = Process(); process.executableURL = runtime; process.arguments = setupArgs + arguments
        let pipe = Pipe(); process.standardOutput = pipe; process.standardError = pipe
        DispatchQueue.global().async {
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
                let result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? ["error": String(data: data, encoding: .utf8) ?? "Runtime failed"]
                DispatchQueue.main.async {
                    self.busy = false
                    if process.terminationStatus != 0 || result["error"] != nil { self.showError(result["error"] as? String ?? "Runtime failed") }
                    else { completion(result) }
                }
            } catch { DispatchQueue.main.async { self.busy = false; self.showError(error.localizedDescription) } }
        }
    }
    func showError(_ message: String) {
        controls(true); playButton.isEnabled = pcReady; genesisButton.isEnabled = pcReady
        status.stringValue = "Setup could not complete"
        detail.stringValue = message
    }
    @objc func choosePC() { choose(folder: true) }
    @objc func chooseGenesis() { choose(folder: false) }
    func choose(folder: Bool) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = folder; panel.canChooseFiles = !folder; panel.allowsMultipleSelection = false
        panel.message = folder ? "Choose your extracted original PC game folder." : "Choose the supported original raw Genesis ROM."
        panel.prompt = "Import"
        panel.beginSheetModal(for: window) { response in
            if response == .OK, let url = panel.url {
                self.status.stringValue = "Checking and importing…"
                self.call([folder ? "--game" : "--genesis", url.path], completion: { self.refresh($0) })
            }
        }
    }
    @objc func play() {
        if busy || running != nil { return }; busy = true; controls(false)
        status.stringValue = "Game session active"; detail.stringValue = "The game opens in a separate window after its resources are ready. Close that window to return here. Your save states are preserved."
        let process = Process(); process.executableURL = runtime; process.arguments = setupArgs + ["--play"]
        let pipe = Pipe(); process.standardOutput = pipe; process.standardError = pipe
        running = process
        DispatchQueue.global().async {
            do {
                try process.run()
                // Consume output without accumulating an unbounded transcript.
                var tail = Data()
                while true { let data = pipe.fileHandleForReading.availableData; if data.isEmpty { break }; tail.append(data); if tail.count > 16384 { tail = Data(tail.suffix(16384)) } }
                process.waitUntilExit()
                let message = String(data: tail, encoding: .utf8) ?? "Game exited"
                DispatchQueue.main.async {
                    self.running = nil; self.busy = false
                    self.window.makeKeyAndOrderFront(nil)
                    if process.terminationStatus != 0 { self.showError(message) } else { self.refresh() }
                }
            } catch { DispatchQueue.main.async { self.running = nil; self.busy = false; self.showError(error.localizedDescription) } }
        }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if running != nil || busy {
            let alert = NSAlert(); alert.messageText = "Close the game window before quitting Abrams."; alert.informativeText = "This lets the original simulation finish saving its profile safely."; alert.runModal(); return .terminateCancel
        }
        return .terminateNow
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { running == nil && !busy }
}
let delegate = Launcher()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
