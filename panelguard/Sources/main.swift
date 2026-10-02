import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Darwin
import Foundation

private let appVersion = "1.1.0"
private let stateDirectoryName = "PanelGuard"
private let stateFileName = "guard-state-v2.json"

private struct GuardState: Codable {
    var active: Bool
    var physicalDisplayID: UInt32
    var restoreBrightness: Float
    var enforceDisconnect: Bool
    var restoreOnExit: Bool
    var autoRestoreAt: TimeInterval?
    var parentPID: Int32
}

private enum StateStore {
    static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(stateDirectoryName, isDirectory: true)
    }
    static var stateURL: URL { directoryURL.appendingPathComponent(stateFileName) }
    static func load(from url: URL = stateURL) -> GuardState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(GuardState.self, from: data)
    }
    static func save(_ state: GuardState, to url: URL = stateURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
    }
}

private final class BrightnessController {
    static let shared = BrightnessController()
    typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private let getter: GetBrightness?
    private let setter: SetBrightness?

    private init() {
        let h = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW | RTLD_LOCAL)
        if let h, let s = dlsym(h, "DisplayServicesGetBrightness") { getter = unsafeBitCast(s, to: GetBrightness.self) } else { getter = nil }
        if let h, let s = dlsym(h, "DisplayServicesSetBrightness") { setter = unsafeBitCast(s, to: SetBrightness.self) } else { setter = nil }
    }

    var apiAvailable: Bool { getter != nil && setter != nil }

    func builtInDisplay() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return nil }
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    func get(_ display: CGDirectDisplayID) -> Float? {
        guard let getter else { return nil }
        var v: Float = 0
        return getter(display, &v) == 0 ? v : nil
    }

    @discardableResult
    func set(_ value: Float, display: CGDirectDisplayID) -> Bool {
        guard let setter else { return false }
        return setter(display, min(max(value, 0), 1)) == 0
    }
}

private final class DisplayConnectionController {
    static let shared = DisplayConnectionController()
    typealias CoreDisplaySetUserEnabled = @convention(c) (CGDirectDisplayID, Bool) -> Int32
    typealias SkyLightConfigureEnabled = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError

    private let coreSetEnabled: CoreDisplaySetUserEnabled?
    private let skySetEnabled: SkyLightConfigureEnabled?

    private init() {
        let core = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY)
        if let core, let s = dlsym(core, "CoreDisplay_Display_SetUserEnabled") {
            coreSetEnabled = unsafeBitCast(s, to: CoreDisplaySetUserEnabled.self)
        } else { coreSetEnabled = nil }

        let sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        if let sky, let s = dlsym(sky, "SLSConfigureDisplayEnabled") ?? dlsym(sky, "CGSConfigureDisplayEnabled") {
            skySetEnabled = unsafeBitCast(s, to: SkyLightConfigureEnabled.self)
        } else { skySetEnabled = nil }
    }

    var apiAvailable: Bool { coreSetEnabled != nil || skySetEnabled != nil }
    var methodDescription: String {
        if coreSetEnabled != nil { return "CoreDisplay (Ventura-compatible)" }
        if skySetEnabled != nil { return "SkyLight" }
        return "Unavailable"
    }

    private func stateMatches(_ enabled: Bool, display: CGDirectDisplayID) -> Bool {
        enabled ? (CGDisplayIsOnline(display) != 0 && CGDisplayIsActive(display) != 0)
                : (CGDisplayIsOnline(display) == 0 || CGDisplayIsActive(display) == 0)
    }

    private func waitForState(_ enabled: Bool, display: CGDirectDisplayID, timeout: TimeInterval = 1.8) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if stateMatches(enabled, display: display) { return true }
            usleep(100_000)
        } while Date() < deadline
        return stateMatches(enabled, display: display)
    }

    @discardableResult
    func setEnabled(_ enabled: Bool, display: CGDirectDisplayID) -> Bool {
        if stateMatches(enabled, display: display) { return true }

        if let coreSetEnabled {
            if coreSetEnabled(display, enabled) == 0 && waitForState(enabled, display: display) { return true }
        }

        if let skySetEnabled {
            var config: CGDisplayConfigRef?
            if CGBeginDisplayConfiguration(&config) == .success, let config {
                let result = skySetEnabled(config, display, enabled)
                if result == .success {
                    if CGCompleteDisplayConfiguration(config, .forAppOnly) == .success,
                       waitForState(enabled, display: display) { return true }
                } else { CGCancelDisplayConfiguration(config) }
            }
        }
        return stateMatches(enabled, display: display)
    }
}

private final class GlobalHotkey {
    private let signature: OSType = 0x50474B59
    private let identifier: UInt32 = 1
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) { self.action = action }

    @discardableResult
    func register() -> Bool {
        unregister()
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: signature, id: identifier)
        guard RegisterEventHotKey(UInt32(kVK_ANSI_B), UInt32(cmdKey | optionKey | controlKey), id, GetApplicationEventTarget(), 0, &ref) == noErr,
              let ref else { return false }
        hotKeyRef = ref

        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let opaque = Unmanaged.passUnretained(self).toOpaque()
        let cb: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
            var incoming = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &incoming)
            guard status == noErr, incoming.signature == manager.signature, incoming.id == manager.identifier else { return OSStatus(eventNotHandledErr) }
            DispatchQueue.main.async { manager.action() }
            return noErr
        }
        guard InstallEventHandler(GetApplicationEventTarget(), cb, 1, &type, opaque, &eventHandler) == noErr else {
            unregister(); return false
        }
        return true
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKeyRef = nil; eventHandler = nil
    }
    deinit { unregister() }
}

private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var hotkey: GlobalHotkey!
    private var caffeinate: Process?
    private var watchdog: Process?
    private var pollTimer: Timer?
    private var guardState: GuardState?
    private var virtualHandle: UnsafeMutableRawPointer?
    private var virtualID: CGDirectDisplayID = 0

    private let statusDot = NSTextField(labelWithString: "●")
    private let statusTitle = NSTextField(labelWithString: "Ready")
    private let statusDetail = NSTextField(wrappingLabelWithString: "Checking display control…")
    private let primaryButton = NSButton(title: "Turn Physical Display Off", target: nil, action: nil)
    private let testButton = NSButton(title: "Test for 10 Seconds", target: nil, action: nil)
    private let enforceSwitch = NSSwitch()
    private let restoreSwitch = NSSwitch()
    private let awakeSwitch = NSSwitch()
    private let diagnostics = NSTextField(wrappingLabelWithString: "")
    private let hotkeyLabel = NSTextField(labelWithString: "⌃⌥⌘B")

    private var isGuarded: Bool { guardState?.active == true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        UserDefaults.standard.register(defaults: ["enforceDisconnect": true, "restoreOnExit": true, "keepAwake": true, "lastVisibleBrightness": 0.5])
        recoverStaleState()
        buildWindow(); buildStatusItem(); configureHotkey(); refreshCapability()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.syncFromWatchdog() }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if isGuarded { restoreDisplay(silent: true) }
        destroyVirtualDisplay(); stopCaffeinate(); stopWatchdog(); hotkey?.unregister(); pollTimer?.invalidate()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { window.orderOut(nil); return false }

    private func recoverStaleState() {
        guard var s = StateStore.load(), s.active else { return }
        errno = 0
        let alive = kill(pid_t(s.parentPID), 0) == 0 || errno != ESRCH
        guard !alive else { return }
        if s.restoreOnExit {
            _ = DisplayConnectionController.shared.setEnabled(true, display: s.physicalDisplayID)
            usleep(350_000)
            _ = BrightnessController.shared.set(s.restoreBrightness, display: s.physicalDisplayID)
        }
        s.active = false; try? StateStore.save(s)
    }

    private func configureHotkey() {
        hotkey = GlobalHotkey { [weak self] in self?.toggleGuard() }
        let ok = hotkey.register()
        hotkeyLabel.stringValue = ok ? "⌃⌥⌘B" : "Unavailable — shortcut already in use"
        hotkeyLabel.textColor = ok ? .secondaryLabelColor : .systemOrange
    }

    private func syncFromWatchdog() {
        guard isGuarded, let disk = StateStore.load(), !disk.active else { return }
        guardState = disk; destroyVirtualDisplay(); stopCaffeinate(); updateUI()
    }

    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 600), styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "PanelGuard"; window.titlebarAppearsTransparent = true; window.isMovableByWindowBackground = true; window.center(); window.delegate = self
        window.minSize = NSSize(width: 580, height: 560)

        let bg = NSVisualEffectView(); bg.material = .windowBackground; bg.blendingMode = .behindWindow; bg.state = .active; window.contentView = bg
        let root = NSStackView(); root.orientation = .vertical; root.alignment = .leading; root.spacing = 16; root.translatesAutoresizingMaskIntoConstraints = false; bg.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 30), root.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -30), root.topAnchor.constraint(equalTo: bg.topAnchor, constant: 54), root.bottomAnchor.constraint(lessThanOrEqualTo: bg.bottomAnchor, constant: -24)])

        let title = NSTextField(labelWithString: "PanelGuard"); title.font = .systemFont(ofSize: 30, weight: .bold)
        let subtitle = NSTextField(wrappingLabelWithString: "Private remote access for your iMac. PanelGuard disconnects the physical panel only after a hidden Retina framebuffer is active for RustDesk.")
        subtitle.font = .systemFont(ofSize: 14); subtitle.textColor = .secondaryLabelColor; subtitle.maximumNumberOfLines = 3
        root.addArrangedSubview(title); root.addArrangedSubview(subtitle); root.setCustomSpacing(22, after: subtitle)

        let card = makeCard(); let row = NSStackView(); row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 14; row.translatesAutoresizingMaskIntoConstraints = false; card.addSubview(row); pin(row, to: card, inset: 18)
        let icon = NSImageView(); icon.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: "Displays"); icon.symbolConfiguration = .init(pointSize: 30, weight: .medium); icon.contentTintColor = .labelColor
        let text = NSStackView(); text.orientation = .vertical; text.alignment = .leading; text.spacing = 3
        statusTitle.font = .systemFont(ofSize: 16, weight: .semibold); statusDetail.font = .systemFont(ofSize: 12); statusDetail.textColor = .secondaryLabelColor; statusDetail.maximumNumberOfLines = 3
        text.addArrangedSubview(statusTitle); text.addArrangedSubview(statusDetail)
        statusDot.font = .systemFont(ofSize: 16, weight: .bold); statusDot.textColor = .systemGreen
        row.addArrangedSubview(icon); row.addArrangedSubview(text); row.addArrangedSubview(NSView()); row.addArrangedSubview(statusDot)
        root.addArrangedSubview(card); card.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true; card.heightAnchor.constraint(greaterThanOrEqualToConstant: 98).isActive = true

        primaryButton.target = self; primaryButton.action = #selector(primaryAction); primaryButton.bezelStyle = .rounded; primaryButton.controlSize = .large; primaryButton.font = .systemFont(ofSize: 15, weight: .semibold); primaryButton.bezelColor = .controlAccentColor; primaryButton.contentTintColor = .white
        root.addArrangedSubview(primaryButton); primaryButton.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true; primaryButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        testButton.target = self; testButton.action = #selector(testAction); testButton.bezelStyle = .rounded; root.addArrangedSubview(testButton); testButton.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let safety = makeCard(); let ss = NSStackView(); ss.orientation = .vertical; ss.alignment = .leading; ss.spacing = 12; ss.translatesAutoresizingMaskIntoConstraints = false; safety.addSubview(ss); pin(ss, to: safety, inset: 16)
        let sh = NSTextField(labelWithString: "Safety & Reliability"); sh.font = .systemFont(ofSize: 13, weight: .semibold); ss.addArrangedSubview(sh)
        enforceSwitch.state = UserDefaults.standard.bool(forKey: "enforceDisconnect") ? .on : .off; restoreSwitch.state = UserDefaults.standard.bool(forKey: "restoreOnExit") ? .on : .off; awakeSwitch.state = UserDefaults.standard.bool(forKey: "keepAwake") ? .on : .off
        for t in [enforceSwitch, restoreSwitch, awakeSwitch] { t.target = self; t.action = #selector(settingsChanged) }
        ss.addArrangedSubview(settingRow("Re-disconnect the physical panel if macOS brings it back", enforceSwitch))
        ss.addArrangedSubview(settingRow("Restore the physical display if PanelGuard closes unexpectedly", restoreSwitch))
        ss.addArrangedSubview(settingRow("Keep the Mac and remote framebuffer awake while guarded", awakeSwitch))
        root.addArrangedSubview(safety); safety.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let recovery = NSStackView(); recovery.orientation = .horizontal; recovery.alignment = .centerY
        let rl = NSTextField(labelWithString: "Emergency restore shortcut"); rl.font = .systemFont(ofSize: 12, weight: .medium); hotkeyLabel.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        recovery.addArrangedSubview(rl); recovery.addArrangedSubview(NSView()); recovery.addArrangedSubview(hotkeyLabel); root.addArrangedSubview(recovery); recovery.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        diagnostics.font = .monospacedSystemFont(ofSize: 10.5, weight: .regular); diagnostics.textColor = .tertiaryLabelColor; diagnostics.maximumNumberOfLines = 4; root.addArrangedSubview(diagnostics)
        let footer = NSTextField(labelWithString: "Local-only • No network access • Intel macOS Ventura 13+ • PanelGuard \(appVersion)"); footer.font = .systemFont(ofSize: 10.5); footer.textColor = .tertiaryLabelColor; root.addArrangedSubview(footer)
    }

    private func makeCard() -> NSVisualEffectView { let v = NSVisualEffectView(); v.material = .contentBackground; v.blendingMode = .withinWindow; v.state = .active; v.wantsLayer = true; v.layer?.cornerRadius = 14; v.translatesAutoresizingMaskIntoConstraints = false; return v }
    private func pin(_ view: NSView, to c: NSView, inset: CGFloat) { NSLayoutConstraint.activate([view.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: inset), view.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -inset), view.topAnchor.constraint(equalTo: c.topAnchor, constant: inset), view.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -inset)]) }
    private func settingRow(_ title: String, _ control: NSView) -> NSStackView { let r = NSStackView(); r.orientation = .horizontal; r.alignment = .centerY; let l = NSTextField(labelWithString: title); l.font = .systemFont(ofSize: 12.5); r.addArrangedSubview(l); r.addArrangedSubview(NSView()); r.addArrangedSubview(control); r.widthAnchor.constraint(equalToConstant: 535).isActive = true; return r }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength); statusItem.button?.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: "PanelGuard")
        let menu = NSMenu()
        let show = NSMenuItem(title: "Show PanelGuard", action: #selector(showWindow), keyEquivalent: ""); show.target = self; menu.addItem(show)
        let toggle = NSMenuItem(title: "Turn Physical Display Off", action: #selector(primaryAction), keyEquivalent: ""); toggle.target = self; toggle.tag = 1001; menu.addItem(toggle)
        let test = NSMenuItem(title: "Test for 10 Seconds", action: #selector(testAction), keyEquivalent: ""); test.target = self; test.tag = 1002; menu.addItem(test)
        menu.addItem(.separator()); let quit = NSMenuItem(title: "Quit PanelGuard", action: #selector(quitApp), keyEquivalent: "q"); quit.target = self; menu.addItem(quit); statusItem.menu = menu
    }

    @objc private func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc private func quitApp() { if isGuarded { restoreDisplay(silent: true) }; NSApp.terminate(nil) }
    @objc private func primaryAction() { toggleGuard() }
    @objc private func testAction() { if !isGuarded { activateGuard(autoRestoreAfter: 10) } }
    @objc private func settingsChanged() {
        let e = enforceSwitch.state == .on, r = restoreSwitch.state == .on, a = awakeSwitch.state == .on
        UserDefaults.standard.set(e, forKey: "enforceDisconnect"); UserDefaults.standard.set(r, forKey: "restoreOnExit"); UserDefaults.standard.set(a, forKey: "keepAwake")
        if var s = guardState, s.active { s.enforceDisconnect = e; s.restoreOnExit = r; guardState = s; try? StateStore.save(s); if a { startCaffeinate() } else { stopCaffeinate() } }
    }

    fileprivate func toggleGuard() { isGuarded ? restoreDisplay() : activateGuard(autoRestoreAfter: nil) }

    private func createVirtualDisplay(for physical: CGDirectDisplayID) -> Bool {
        if virtualHandle != nil, virtualID != 0, CGDisplayIsActive(virtualID) != 0 { return true }
        guard PGVirtualDisplayAPISupported() != 0, let mode = CGDisplayCopyDisplayMode(physical) else { return false }
        var id: UInt32 = 0
        let refresh = mode.refreshRate > 1 ? mode.refreshRate : 60
        guard let h = PGCreateVirtualDisplay(UInt32(mode.pixelWidth), UInt32(mode.pixelHeight), refresh, &id), id != 0 else { return false }
        virtualHandle = h; virtualID = id
        let deadline = Date().addingTimeInterval(2.5)
        repeat {
            if CGDisplayIsOnline(id) != 0 && CGDisplayIsActive(id) != 0 { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        destroyVirtualDisplay(); return false
    }

    private func destroyVirtualDisplay() { if let h = virtualHandle { PGDestroyVirtualDisplay(h) }; virtualHandle = nil; virtualID = 0 }

    private func activateGuard(autoRestoreAfter: TimeInterval?) {
        let b = BrightnessController.shared, c = DisplayConnectionController.shared
        guard c.apiAvailable else { showError("Physical display disconnect is unavailable", "PanelGuard could not load the Ventura-compatible CoreDisplay/SkyLight API."); return }
        guard PGVirtualDisplayAPISupported() != 0 else { showError("Virtual display support is unavailable", "PanelGuard could not create the hidden framebuffer required for safe remote access."); return }
        guard let physical = b.builtInDisplay(), let current = b.get(physical) else { showError("Built-in iMac display not found", "PanelGuard could not identify and read the built-in Apple display."); return }

        let stored = Float(UserDefaults.standard.double(forKey: "lastVisibleBrightness")); let restore = current > 0.015 ? current : max(stored, 0.5)
        if current > 0.015 { UserDefaults.standard.set(Double(current), forKey: "lastVisibleBrightness") }

        statusTitle.stringValue = "Preparing private display…"; statusDetail.stringValue = "Creating and verifying a hidden Retina framebuffer before the physical panel is disconnected."; primaryButton.isEnabled = false; testButton.isEnabled = false
        guard createVirtualDisplay(for: physical) else { refreshCapability(); showError("Couldn’t create the remote framebuffer", "PanelGuard kept the physical display on. Restart the app and try again."); return }

        var s = GuardState(active: true, physicalDisplayID: physical, restoreBrightness: restore, enforceDisconnect: enforceSwitch.state == .on, restoreOnExit: restoreSwitch.state == .on, autoRestoreAt: autoRestoreAfter.map { Date().timeIntervalSince1970 + $0 }, parentPID: getpid())
        do { try StateStore.save(s) } catch { destroyVirtualDisplay(); refreshCapability(); showError("Couldn’t arm crash recovery", "PanelGuard refused to disconnect the display because the safety state could not be saved."); return }
        guardState = s; startWatchdog(); if awakeSwitch.state == .on { startCaffeinate() }
        _ = b.set(0, display: physical)

        guard c.setEnabled(false, display: physical), CGDisplayIsActive(virtualID) != 0 else {
            stopWatchdog(); s.active = false; guardState = s; try? StateStore.save(s); _ = c.setEnabled(true, display: physical); usleep(350_000); _ = b.set(restore, display: physical); destroyVirtualDisplay(); stopCaffeinate(); refreshCapability(); showError("The iMac panel did not disconnect safely", "PanelGuard detected an incomplete transition and restored the physical display instead of leaving a partial state."); return
        }
        updateUI()
    }

    private func restoreDisplay(silent: Bool = false) {
        guard var s = guardState ?? StateStore.load(), s.active else { guardState = nil; destroyVirtualDisplay(); updateUI(); return }
        stopWatchdog(); let old = s; s.active = false; try? StateStore.save(s)
        if DisplayConnectionController.shared.setEnabled(true, display: old.physicalDisplayID) {
            usleep(350_000); _ = BrightnessController.shared.set(old.restoreBrightness, display: old.physicalDisplayID); UserDefaults.standard.set(Double(old.restoreBrightness), forKey: "lastVisibleBrightness"); guardState = s; destroyVirtualDisplay(); stopCaffeinate(); updateUI()
        } else {
            guardState = old; try? StateStore.save(old); startWatchdog(); updateUI()
            if !silent { showError("Physical display restore needs attention", "PanelGuard kept the virtual display alive so RustDesk remains usable. Try ⌃⌥⌘B again; if needed, log out or restart the Mac to force the built-in display to reconnect.") }
        }
    }

    private func startWatchdog() {
        if let watchdog, watchdog.isRunning { return }
        guard let exe = Bundle.main.executableURL else { return }
        let p = Process(); p.executableURL = exe; p.arguments = ["--watchdog", String(getpid()), StateStore.stateURL.path]
        do { try p.run(); watchdog = p } catch { watchdog = nil; if let s = guardState { _ = DisplayConnectionController.shared.setEnabled(true, display: s.physicalDisplayID); _ = BrightnessController.shared.set(s.restoreBrightness, display: s.physicalDisplayID); var i = s; i.active = false; guardState = i; try? StateStore.save(i) }; destroyVirtualDisplay(); stopCaffeinate(); showError("Safety watchdog couldn’t start", "PanelGuard kept the physical display available rather than operating without crash recovery.") }
    }
    private func stopWatchdog() { if let watchdog, watchdog.isRunning { watchdog.terminate() }; watchdog = nil }
    private func startCaffeinate() { if let caffeinate, caffeinate.isRunning { return }; let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate"); p.arguments = ["-d", "-i", "-s", "-w", String(getpid())]; do { try p.run(); caffeinate = p } catch { caffeinate = nil } }
    private func stopCaffeinate() { if let caffeinate, caffeinate.isRunning { caffeinate.terminate() }; caffeinate = nil }

    private func refreshCapability() {
        let b = BrightnessController.shared, c = DisplayConnectionController.shared, p = b.builtInDisplay(); let virtualReady = PGVirtualDisplayAPISupported() != 0
        if let p, let v = b.get(p), v > 0.015 { UserDefaults.standard.set(Double(v), forKey: "lastVisibleBrightness") }
        diagnostics.stringValue = "Disconnect: \(c.methodDescription)   Virtual display: \(virtualReady ? "ready" : "unavailable")\nBuilt-in display: \(p.map { String(format: "0x%08X", $0) } ?? "not found")   Brightness API: \(b.apiAvailable ? "ready" : "unavailable")"
        primaryButton.isEnabled = c.apiAvailable && virtualReady && p != nil && b.apiAvailable; testButton.isEnabled = primaryButton.isEnabled && !isGuarded; updateUI()
    }

    private func updateUI() {
        if isGuarded {
            let testing = guardState?.autoRestoreAt != nil; statusDot.textColor = .systemIndigo; statusTitle.stringValue = testing ? "Safe test in progress" : "Physical iMac display disconnected"; statusDetail.stringValue = testing ? "The physical panel is off. The hidden Retina display remains available to RustDesk and will restore automatically after 10 seconds." : "The physical panel is disconnected while the hidden Retina framebuffer stays active for remote access."; primaryButton.title = "Restore Physical Display"; primaryButton.bezelColor = .systemGray; primaryButton.isEnabled = true; testButton.isEnabled = false; statusItem.button?.image = NSImage(systemSymbolName: "display.slash", accessibilityDescription: "PanelGuard active"); statusItem.menu?.item(withTag: 1001)?.title = "Restore Physical Display"; statusItem.menu?.item(withTag: 1002)?.isEnabled = false
            diagnostics.stringValue = "Disconnect: \(DisplayConnectionController.shared.methodDescription)   Virtual display: \(virtualID == 0 ? "starting" : String(format: "0x%08X", virtualID))\nPhysical display: \(String(format: "0x%08X", guardState?.physicalDisplayID ?? 0))   Physical active: \((guardState.map { CGDisplayIsActive($0.physicalDisplayID) != 0 } ?? false) ? "YES" : "NO")"
        } else {
            statusDot.textColor = .systemGreen; statusTitle.stringValue = "Ready"; statusDetail.stringValue = "The physical iMac display is visible. PanelGuard will create a separate remote framebuffer before disconnecting it."; primaryButton.title = "Turn Physical Display Off"; primaryButton.bezelColor = .controlAccentColor; statusItem.button?.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: "PanelGuard"); statusItem.menu?.item(withTag: 1001)?.title = "Turn Physical Display Off"; statusItem.menu?.item(withTag: 1002)?.isEnabled = primaryButton.isEnabled
        }
    }

    private func showError(_ title: String, _ detail: String) { guard window != nil else { return }; let a = NSAlert(); a.alertStyle = .warning; a.messageText = title; a.informativeText = detail; a.addButton(withTitle: "OK"); a.beginSheetModal(for: window) }
}

private func runWatchdog(_ args: [String]) -> Int32 {
    guard args.count >= 4, let parentValue = Int32(args[2]) else { return 64 }
    let parent = pid_t(parentValue), url = URL(fileURLWithPath: args[3]), b = BrightnessController.shared, c = DisplayConnectionController.shared
    while true {
        guard var s = StateStore.load(from: url), s.active else { return 0 }
        if let deadline = s.autoRestoreAt, Date().timeIntervalSince1970 >= deadline { _ = c.setEnabled(true, display: s.physicalDisplayID); usleep(350_000); _ = b.set(s.restoreBrightness, display: s.physicalDisplayID); s.active = false; try? StateStore.save(s, to: url); return 0 }
        errno = 0; let gone = kill(parent, 0) != 0 && errno == ESRCH
        if gone { if s.restoreOnExit { _ = c.setEnabled(true, display: s.physicalDisplayID); usleep(350_000); _ = b.set(s.restoreBrightness, display: s.physicalDisplayID) }; s.active = false; try? StateStore.save(s, to: url); return 0 }
        if s.enforceDisconnect, CGDisplayIsActive(s.physicalDisplayID) != 0 { _ = b.set(0, display: s.physicalDisplayID); _ = c.setEnabled(false, display: s.physicalDisplayID) }
        usleep(300_000)
    }
}

private func runSelfTest() -> Int32 {
    let b = BrightnessController.shared, c = DisplayConnectionController.shared, v = PGVirtualDisplayAPISupported() != 0
    print("PanelGuard \(appVersion)"); print("DisplayServices symbols: \(b.apiAvailable ? "OK" : "FAIL")"); print("Display disconnect API: \(c.methodDescription)"); print("CGVirtualDisplay classes: \(v ? "OK" : "FAIL")")
    if let d = b.builtInDisplay() { print(String(format: "Built-in display: 0x%08X", d)); if let m = CGDisplayCopyDisplayMode(d) { print("Current pixel mode: \(m.pixelWidth)x\(m.pixelHeight)") }; if let x = b.get(d) { print(String(format: "Brightness read: %.3f", x)) } } else { print("Built-in display: none") }
    return b.apiAvailable && c.apiAvailable && v ? 0 : 2
}

let arguments = CommandLine.arguments
if arguments.contains("--version") { print(appVersion); exit(0) }
if arguments.contains("--self-test") { exit(runSelfTest()) }
if arguments.count > 1, arguments[1] == "--watchdog" { exit(runWatchdog(arguments)) }
let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
