import AppKit
import WebKit

// Native vibrancy provides the glass material without a live game render pass.
final class GlassPanel: NSVisualEffectView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        refreshTransparency()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refreshTransparency), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("Programmatic view") }
    @objc func refreshTransparency() {
        let opaque = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        layer?.backgroundColor = NSColor(calibratedRed: 0.09, green: 0.12, blue: 0.15, alpha: opaque ? 1 : 0.58).cgColor
        for view in window?.contentView?.subviews ?? [] where view is LauncherBackdrop { view.needsDisplay = true }
    }
    deinit { NSWorkspace.shared.notificationCenter.removeObserver(self) }
}

final class LauncherBackdrop: NSView {
    var artwork: NSImage?
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.10, alpha: 1).setFill()
        bounds.fill()
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
              let artwork, artwork.size.width > 0, artwork.size.height > 0 else { return }
        let scale = max(bounds.width / artwork.size.width, bounds.height / artwork.size.height)
        let size = NSSize(width: artwork.size.width * scale, height: artwork.size.height * scale)
        artwork.draw(in: NSRect(x: (bounds.width-size.width)/2, y: (bounds.height-size.height)/2, width: size.width, height: size.height), from: .zero, operation: .sourceOver, fraction: 0.18)
    }
}

// A reviewed document stays inside setup. Navigation never leaves this local library.
final class LocalReferenceNavigation: NSObject, WKNavigationDelegate, WKUIDelegate {
    let directory: URL
    init(directory: URL) { self.directory = directory.resolvingSymlinksInPath().standardizedFileURL }
    func allowed(_ url: URL, names: [String]) -> Bool {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        return url.isFileURL && resolved.deletingLastPathComponent() == directory && names.contains(resolved.lastPathComponent)
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        if allowed(url, names: ["keyboard-controls.html", "field-guide.html"]) && action.targetFrame?.isMainFrame == true {
            decisionHandler(.allow); return
        }
        if action.navigationType == .linkActivated && allowed(url, names: ["keyboard-controls.pdf", "field-guide.pdf"]) {
            NSWorkspace.shared.open(url)
        }
        decisionHandler(.cancel)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // New windows, arbitrary external links and script navigation are denied.
        return nil
    }
}

final class Launcher: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 610), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
    let status = NSTextField(wrappingLabelWithString: "Checking your installation…")
    let detail = NSTextField(wrappingLabelWithString: "Your original game files and save states are stored separately from the application.")
    let pcState = NSTextField(labelWithString: "CHECKING")
    let genesisState = NSTextField(labelWithString: "OPTIONAL")
    let progress = NSProgressIndicator()
    var pcButton: NSButton!
    var genesisButton: NSButton!
    var playButton: NSButton!
    var aboutWindow: NSWindow?
    var referencePane: NSView?
    var referenceNavigation: LocalReferenceNavigation?
    var running: Process?
    var busy = false
    var pcReady = false
    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "M1 Abrams Battle Tank Fan Remaster"
    let githubURL = URL(string: "https://github.com/NellInc/Abrams")!
    let cream = NSColor(calibratedRed: 0.95, green: 0.91, blue: 0.81, alpha: 1)
    let muted = NSColor(calibratedRed: 0.69, green: 0.73, blue: 0.76, alpha: 1)
    let accent = NSColor(calibratedRed: 0.84, green: 0.27, blue: 0.24, alpha: 1)
    let runtime = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/runtime/AbramsRuntime/AbramsRuntime")
    var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "Version \(info["AbramsReleaseVersion"] as? String ?? info["CFBundleShortVersionString"] as? String ?? "development") · Build \(info["CFBundleVersion"] as? String ?? "local")"
    }
    var setupArgs: [String] {
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--data-home"), index+1 < args.count { return ["--data-home", args[index+1]] }
        return []
    }

    @discardableResult
    func label(_ text: String, frame: NSRect, size: CGFloat = 13, weight: NSFont.Weight = .regular, color: NSColor? = nil, in view: NSView) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color ?? cream
        field.frame = frame
        view.addSubview(field)
        return field
    }
    func card(_ frame: NSRect, in view: NSView) -> NSView {
        let panel = GlassPanel(frame: frame)
        view.addSubview(panel)
        return panel
    }
    func backdrop(in view: NSView) {
        let background = LauncherBackdrop(frame: view.bounds)
        background.artwork = NSImage(contentsOf: Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/kit/branding/abrams-cover-remastered.png"))
        background.autoresizingMask = [.width, .height]
        view.addSubview(background, positioned: .below, relativeTo: nil)
    }
    func button(_ title: String, action: Selector, frame: NSRect, in view: NSView) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.frame = frame
        button.setAccessibilityLabel(title.replacingOccurrences(of: "…", with: ""))
        view.addSubview(button)
        return button
    }
    func configure(_ target: NSWindow) {
        target.appearance = NSAppearance(named: .darkAqua)
        target.backgroundColor = NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.14, alpha: 1)
        target.titlebarAppearsTransparent = true
        target.isReleasedWhenClosed = false
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu()
        let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        let about = appMenu.addItem(withTitle: "About \(appName)", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); menu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit"); editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let helpItem = NSMenuItem(); menu.addItem(helpItem)
        let helpMenu = NSMenu(title: "Help"); helpItem.submenu = helpMenu
        let controls = helpMenu.addItem(withTitle: "Keyboard controls", action: #selector(openControls), keyEquivalent: "")
        controls.target = self
        let guide = helpMenu.addItem(withTitle: "Scenarios & vehicles", action: #selector(openFieldGuide), keyEquivalent: "")
        guide.target = self
        helpMenu.addItem(.separator())
        let github = helpMenu.addItem(withTitle: "Abrams on GitHub", action: #selector(openGitHub), keyEquivalent: "")
        github.target = self
        NSApp.mainMenu = menu
        NSApp.helpMenu = helpMenu

        configure(window)
        window.title = appName
        window.delegate = self
        let view = window.contentView!
        backdrop(in: view)
        let icon = NSImageView(frame: NSRect(x: 30, y: 470, width: 102, height: 102))
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityLabel("Abrams remaster cover artwork")
        view.addSubview(icon)
        label(appName, frame: NSRect(x: 150, y: 511, width: 580, height: 58), size: 25, weight: .bold, in: view)
        label("Original game by Dynamix · Published by Electronic Arts", frame: NSRect(x: 152, y: 477, width: 575, height: 24), size: 14, color: muted, in: view)
        label("YOUR GAME FILES", frame: NSRect(x: 32, y: 433, width: 400, height: 18), size: 11, weight: .semibold, color: muted, in: view)
        let pc = card(NSRect(x: 30, y: 319, width: 700, height: 105), in: view)
        label("Original PC game", frame: NSRect(x: 18, y: 65, width: 265, height: 24), size: 17, weight: .semibold, in: pc)
        pcState.frame = NSRect(x: 293, y: 69, width: 170, height: 17)
        pcState.font = .systemFont(ofSize: 10, weight: .semibold); pcState.textColor = muted; pc.addSubview(pcState)
        label("Choose the extracted folder containing ABRAMS.COM and SIM.EXE.\nSupported files are verified and copied. Your source stays unchanged.", frame: NSRect(x: 18, y: 15, width: 473, height: 43), size: 12, color: muted, in: pc)
        pcButton = button("Choose PC folder…", action: #selector(choosePC), frame: NSRect(x: 504, y: 34, width: 179, height: 34), in: pc)
        pcButton.keyEquivalent = "i"; pcButton.keyEquivalentModifierMask = [.command]
        pcButton.toolTip = "Import a supported original PC game folder. Source files are never modified."
        let genesis = card(NSRect(x: 30, y: 201, width: 700, height: 105), in: view)
        label("Genesis presentation", frame: NSRect(x: 18, y: 65, width: 265, height: 24), size: 17, weight: .semibold, in: genesis)
        genesisState.frame = NSRect(x: 293, y: 69, width: 170, height: 17)
        genesisState.font = .systemFont(ofSize: 10, weight: .semibold); genesisState.textColor = muted; genesis.addSubview(genesisState)
        label("Optional: add a supported original Genesis ROM for its presentation.\nThe PC game is still required. Import it first to enable this option.", frame: NSRect(x: 18, y: 15, width: 473, height: 43), size: 12, color: muted, in: genesis)
        genesisButton = button("Add Genesis ROM…", action: #selector(chooseGenesis), frame: NSRect(x: 504, y: 34, width: 179, height: 34), in: genesis)
        genesisButton.toolTip = "Optional. Import the original PC game first."

        progress.style = .spinning; progress.controlSize = .small
        progress.frame = NSRect(x: 33, y: 160, width: 16, height: 16)
        progress.isDisplayedWhenStopped = false; progress.setAccessibilityLabel("Working")
        view.addSubview(progress)
        status.font = .systemFont(ofSize: 14, weight: .semibold); status.textColor = cream
        status.frame = NSRect(x: 58, y: 155, width: 665, height: 26); view.addSubview(status)
        status.setAccessibilityLabel("Installation status")
        detail.font = .systemFont(ofSize: 12); detail.textColor = muted
        detail.frame = NSRect(x: 32, y: 86, width: 690, height: 64); detail.isSelectable = true
        view.addSubview(detail)
        detail.setAccessibilityLabel("Installation details")
        let aboutButton = button("About", action: #selector(showAbout), frame: NSRect(x: 28, y: 28, width: 82, height: 32), in: view)
        aboutButton.controlSize = .regular
        let githubButton = button("GitHub ↗", action: #selector(openGitHub), frame: NSRect(x: 112, y: 28, width: 103, height: 32), in: view)
        githubButton.controlSize = .regular
        githubButton.toolTip = "Open the Abrams project in your default browser"
        githubButton.setAccessibilityLabel("Open Abrams on GitHub in your browser")
        let reference = button("Field guide", action: #selector(openFieldGuide), frame: NSRect(x: 224, y: 28, width: 112, height: 32), in: view)
        reference.controlSize = .regular
        reference.toolTip = "Open the offline scenario and vehicle catalogue"
        label(version, frame: NSRect(x: 346, y: 34, width: 196, height: 20), size: 10, color: muted, in: view)
        playButton = button("Play Abrams", action: #selector(play), frame: NSRect(x: 551, y: 25, width: 182, height: 39), in: view)
        playButton.bezelColor = accent; playButton.keyEquivalent = "\r"
        playButton.toolTip = "Launch the simulation after the original PC game has been verified"
        updateControls()
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        refresh()
    }
    func updateControls() {
        let enabled = !busy && running == nil
        pcButton.isEnabled = enabled
        genesisButton.isEnabled = enabled && pcReady
        playButton.isEnabled = enabled && pcReady
        playButton.title = running == nil ? "Play Abrams" : "Game running"
        if busy { progress.startAnimation(nil) } else { progress.stopAnimation(nil) }
    }
    func refresh(_ result: [String: Any]? = nil) {
        guard let result else { call(["--status"], completion: { self.refresh($0) }); return }
        let pc = result["pc_installed"] as? Bool ?? false
        let genesis = result["genesis_enabled"] as? Bool ?? false
        pcReady = pc
        pcState.stringValue = pc ? "VERIFIED" : "REQUIRED TO PLAY"
        pcState.textColor = pc ? .systemGreen : cream
        pcState.setAccessibilityValue(pc ? "Verified and ready" : "Required, not installed")
        genesisState.stringValue = genesis ? "ENABLED · OPTIONAL" : "OPTIONAL"
        genesisState.textColor = genesis ? .systemGreen : muted
        genesisState.setAccessibilityValue(genesis ? "Optional Genesis presentation enabled" : "Optional, not installed")
        pcButton.title = pc ? "Change PC folder…" : "Choose PC folder…"
        pcButton.setAccessibilityLabel(pcButton.title)
        genesisButton.title = genesis ? "Change Genesis ROM…" : "Add Genesis ROM…"
        genesisButton.setAccessibilityLabel(genesisButton.title)
        updateControls()
        status.stringValue = pc ? "Ready to play · \(genesis ? "Genesis presentation" : "PC presentation")" : "Import your original PC game to begin"
        detail.stringValue = (result["problem"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? (pc ? "Game files and save states are kept outside the app.\n\(result["data_home"] as? String ?? "")" : "A separate, supported copy of the original PC game is required. Neither the PC game nor the optional Genesis ROM is included. Choose your PC folder above to get started.")
        detail.toolTip = detail.stringValue
    }
    // Always drain the pipe, retaining only a bounded tail, including for setup failures.
    static func readOutput(_ pipe: Pipe, limit: Int) -> Data {
        var tail = Data()
        while true {
            let data = pipe.fileHandleForReading.availableData
            if data.isEmpty { break }
            tail.append(data)
            if tail.count > limit { tail = Data(tail.suffix(limit)) }
        }
        return tail
    }
    func call(_ arguments: [String], completion: @escaping ([String: Any]) -> Void) {
        if busy || running != nil { return }
        busy = true; updateControls()
        let process = Process(); process.executableURL = runtime; process.arguments = setupArgs + arguments
        let pipe = Pipe(); process.standardOutput = pipe; process.standardError = pipe
        DispatchQueue.global().async {
            do {
                try process.run()
                let data = Self.readOutput(pipe, limit: 65536); process.waitUntilExit()
                let result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? ["error": String(data: data, encoding: .utf8) ?? "The runtime returned an unreadable response."]
                DispatchQueue.main.async {
                    self.busy = false
                    if process.terminationStatus != 0 || result["error"] != nil { self.showError(result["error"] as? String ?? "The runtime could not complete this operation.") }
                    else { completion(result) }
                }
            } catch { DispatchQueue.main.async { self.busy = false; self.showError(error.localizedDescription) } }
        }
    }
    func showError(_ message: String) {
        updateControls()
        status.stringValue = "This operation could not complete"
        let explanation = message.trimmingCharacters(in: .whitespacesAndNewlines)
        detail.stringValue = explanation.isEmpty ? "The runtime exited without an explanation. Please try again or check the GitHub project for support." : explanation
        detail.toolTip = detail.stringValue
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Abrams could not complete the operation"
        alert.informativeText = String(detail.stringValue.prefix(1800))
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }
    @objc func choosePC() { choose(folder: true) }
    @objc func chooseGenesis() { choose(folder: false) }
    func choose(folder: Bool) {
        guard !busy, running == nil, folder || pcReady else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = folder; panel.canChooseFiles = !folder; panel.allowsMultipleSelection = false
        panel.title = folder ? "Import original PC game" : "Import optional Genesis ROM"
        panel.message = folder ? "Choose the extracted folder containing ABRAMS.COM and SIM.EXE. Supported files will be verified and copied. Your source folder will stay unchanged." : "Choose a supported original raw Genesis ROM. This adds presentation assets; the imported PC game remains required. Your ROM will stay unchanged."
        panel.prompt = "Verify & Import"
        panel.beginSheetModal(for: window) { response in
            if response == .OK, let url = panel.url {
                self.status.stringValue = "Verifying and importing \(folder ? "PC game files" : "Genesis presentation")…"
                self.detail.stringValue = "Please keep Abrams open until verification finishes. Your source files will not be changed."
                self.call([folder ? "--game" : "--genesis", url.path], completion: { self.refresh($0) })
            }
        }
    }
    @objc func play() {
        guard pcReady, !busy, running == nil else { return }
        busy = true
        status.stringValue = "Starting the simulation…"
        detail.stringValue = "The game opens in a separate window. Close the game window to return here and finish saving safely."
        let process = Process(); process.executableURL = runtime; process.arguments = setupArgs + ["--play"]
        let pipe = Pipe(); process.standardOutput = pipe; process.standardError = pipe
        running = process; updateControls()
        DispatchQueue.global().async {
            do {
                try process.run()
                DispatchQueue.main.async { self.status.stringValue = "Game session active" }
                let tail = Self.readOutput(pipe, limit: 16384)
                process.waitUntilExit()
                let message = String(data: tail, encoding: .utf8) ?? "The game exited unexpectedly."
                DispatchQueue.main.async {
                    self.running = nil; self.busy = false
                    self.window.makeKeyAndOrderFront(nil)
                    if process.terminationStatus != 0 { self.showError(message) } else { self.refresh() }
                }
            } catch { DispatchQueue.main.async { self.running = nil; self.busy = false; self.showError(error.localizedDescription) } }
        }
    }
    @objc func openGitHub() { NSWorkspace.shared.open(githubURL) }
    @objc func openControls() { openReference("keyboard-controls.html") }
    @objc func openFieldGuide() { openReference("field-guide.html") }
    func openReference(_ name: String) {
        guard ["keyboard-controls.html", "field-guide.html"].contains(name) else { return }
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/kit/docs/player-reference/" + name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            showError("The offline reference is missing. Please reinstall the complete application.")
            return
        }
        let directory = url.deletingLastPathComponent()
        guard directory.resolvingSymlinksInPath().standardizedFileURL == directory.standardizedFileURL else {
            showError("The offline reference directory is invalid. Reinstall the complete application."); return
        }
        let navigation = LocalReferenceNavigation(directory: directory)
        guard navigation.allowed(url, names: ["keyboard-controls.html", "field-guide.html"]) else {
            showError("The offline reference path is invalid. Reinstall the complete application."); return
        }
        closeReference()
        guard let host = window.contentView else { return }
        let pane = GlassPanel(frame: host.bounds)
        pane.autoresizingMask = [.width, .height]
        host.addSubview(pane)
        label(name == "keyboard-controls.html" ? "Keyboard controls" : "Field guide", frame: NSRect(x: 24, y: host.bounds.height-51, width: 440, height: 30), size: 22, weight: .semibold, in: pane)
        let back = button("Back to setup", action: #selector(closeReference), frame: NSRect(x: host.bounds.width-174, y: host.bounds.height-54, width: 150, height: 34), in: pane)
        back.autoresizingMask = [.minXMargin, .minYMargin]
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: NSRect(x: 16, y: 16, width: host.bounds.width-32, height: host.bounds.height-82), configuration: configuration)
        web.autoresizingMask = [.width, .height]
        web.navigationDelegate = navigation
        web.uiDelegate = navigation
        web.setAccessibilityLabel("Offline Abrams player reference")
        pane.addSubview(web)
        referenceNavigation = navigation
        referencePane = pane
        web.loadFileURL(url, allowingReadAccessTo: navigation.directory)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(web)
    }
    @objc func closeReference() {
        referencePane?.removeFromSuperview()
        referencePane = nil
        referenceNavigation = nil
        if pcReady { window.makeFirstResponder(playButton) }
    }
    func originalCredits() -> String {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/kit/docs/player-reference/credits.json")
        guard let data = try? Data(contentsOf: url),
              let credits = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let rows = credits["rows"] as? [[String: Any]] else { return "Original game by Dynamix. Published by Electronic Arts." }
        return "Original game by Dynamix · Published by Electronic Arts\n" + rows.map { row in
            let role = row["role"] as? String ?? ""
            let names = row["names"] as? [String] ?? []
            return role + ": " + names.joined(separator: ", ")
        }.joined(separator: "\n") + "\n" + (credits["copyright"] as? String ?? "Original game copyright 1988, 1989 Dynamix, Inc.")
    }
    @objc func showAbout() {
        if let aboutWindow { aboutWindow.makeKeyAndOrderFront(nil); return }
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 570), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        configure(panel); panel.title = "About \(appName)"
        let view = panel.contentView!
        backdrop(in: view)
        _ = card(NSRect(x: 20, y: 73, width: 580, height: 365), in: view)
        let icon = NSImageView(frame: NSRect(x: 28, y: 435, width: 90, height: 100))
        icon.image = NSApp.applicationIconImage; icon.imageScaling = .scaleProportionallyUpOrDown; view.addSubview(icon)
        label(appName, frame: NSRect(x: 140, y: 495, width: 452, height: 34), size: 20, weight: .bold, in: view)
        label("Independent, unofficial fan remaster", frame: NSRect(x: 142, y: 467, width: 447, height: 25), size: 14, color: muted, in: view)
        label(version, frame: NSRect(x: 142, y: 443, width: 445, height: 20), size: 12, color: muted, in: view)
        label("Dedicated to David “Ming” Kenny", frame: NSRect(x: 32, y: 400, width: 555, height: 29), size: 19, weight: .semibold, in: view)
        label("Original game by Dynamix.", frame: NSRect(x: 32, y: 369, width: 555, height: 22), size: 14, color: muted, in: view)
        label("Remastered by Nell Watson", frame: NSRect(x: 32, y: 343, width: 555, height: 22), size: 14, weight: .semibold, in: view)
        label("Original creators", frame: NSRect(x: 32, y: 308, width: 555, height: 27), size: 19, weight: .semibold, color: cream, in: view)
        let rights = "This project asserts no ownership, moral rights or other rights over the original game content. Original copyrights and trademarks remain with their respective rights holders. This independent remaster is not affiliated with or endorsed by them.\n\nRemaster code and asset contributions are free under the licences included with this release. This does not change the rights in the original game content.\n\nA separate, supported copy of the original PC game is required. An original Genesis ROM is optional. Neither is bundled with this application."
        let scroll = NSScrollView(frame: NSRect(x: 32, y: 83, width: 555, height: 221))
        scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 535, height: 620))
        text.isEditable = false; text.isSelectable = true; text.drawsBackground = false
        text.font = .systemFont(ofSize: 14); text.textColor = cream
        text.textContainerInset = NSSize(width: 2, height: 6)
        text.isVerticallyResizable = true; text.isHorizontallyResizable = false
        text.textContainer?.widthTracksTextView = true
        text.string = originalCredits() + "\n\nGame content & licensing\n\n" + rights
        scroll.documentView = text; view.addSubview(scroll)
        _ = button("View project on GitHub ↗", action: #selector(openGitHub), frame: NSRect(x: 27, y: 26, width: 233, height: 35), in: view)
        let close = button("Close", action: #selector(closeAbout), frame: NSRect(x: 490, y: 26, width: 102, height: 35), in: view)
        close.keyEquivalent = "\u{1b}"
        aboutWindow = panel; panel.center(); panel.makeKeyAndOrderFront(nil)
    }
    @objc func closeAbout() { aboutWindow?.close() }
    func canCloseLauncher() -> Bool {
        if running != nil || busy {
            let alert = NSAlert()
            alert.messageText = running != nil ? "Close the game window before quitting Abrams." : "Please wait for setup to finish."
            alert.informativeText = running != nil ? "This lets the original simulation finish saving its profile safely." : "Verification or import is in progress. Keep Abrams open until it completes."
            alert.runModal()
            return false
        }
        return true
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { canCloseLauncher() }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { canCloseLauncher() ? .terminateNow : .terminateCancel }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { running == nil && !busy }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { window.makeKeyAndOrderFront(nil) }
        return true
    }
}
let delegate = Launcher()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
