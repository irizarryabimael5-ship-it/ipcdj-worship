import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Darwin
import Foundation

private let appVersion = "1.0.0"
private let stateDirectoryName = "PanelGuard"
private let stateFileName = "guard-state.json"

private struct GuardState: Codable {
    var active: Bool
    var displayID: UInt32
    var restoreBrightness: Float
    var enforceZero: Bool
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
        let data = try JSONEncoder().encode(state)
        try data.write(to: url, options: .atomic)
    }

    static func markInactive(url: URL = stateURL) {
        guard var state = load(from: url) else { return }
        state.active = false
        try? save(state, to: url)
    }
}

private final class BrightnessController {
    static let shared = BrightnessController()

    typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private var handle: UnsafeMutableRawPointer?
    private var getter: GetBrightness?
    private var setter: SetBrightness?

    private init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        handle = dlopen(path, RTLD_NOW | RTLD_LOCAL)
        if let handle {
            if let symbol = dlsym(handle, "DisplayServicesGetBrightness") {
                getter = unsafeBitCast(symbol, to: GetBrightness.self)
            }
            if let symbol = dlsym(handle, "DisplayServicesSetBrightness") {
                setter = unsafeBitCast(symbol, to: SetBrightness.self)
            }
        }
    }

    var apiAvailable: Bool { getter != nil && setter != nil }

    func builtInDisplay() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return nil }
        return displays.prefix(Int(count)).first(where: { CGDisplayIsBuiltin($0) != 0 })
    }

    func get(_ display: CGDirectDisplayID) -> Float? {
        guard let getter else { return nil }
        var value: Float = 0
        guard getter(display, &value) == 0 else { return nil }
        return value
    }

    @discardableResult
    func set(_ value: Float, display: CGDirectDisplayID) -> Bool {
        guard let setter else { return false }
        let clamped = min(max(value, 0), 1)
        return setter(display, clamped) == 0
    }
}

private final class GlobalHotkey {
    private let signature: OSType = 0x50474B59
    private let identifier: UInt32 = 1
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @discardableResult
    func register() -> Bool {
        unregister()

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: identifier)
        let modifiers = UInt32(cmdKey | optionKey | controlKey)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_B),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard registerStatus == noErr, let ref else { return false }
        hotKeyRef = ref

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let opaque = Unmanaged.passUnretained(self).toOpaque()
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
            var incoming = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &incoming
            )
            guard status == noErr,
                  incoming.signature == manager.signature,
                  incoming.id == manager.identifier else {
                return OSStatus(eventNotHandledErr)
            }
            DispatchQueue.main.async { manager.action() }
            return noErr
        }

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            opaque,
            &eventHandler
        )
        if installStatus != noErr {
            unregister()
            return false
        }
        return true
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKeyRef = nil
        eventHandler = nil
    }

    deinit { unregister() }
}

private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var hotkey: GlobalHotkey!
    private var caffeinate: Process?
    private var watchdog: Process?
    private var guardState: GuardState?
    private var testTimer: Timer?

    private let statusDot = NSTextField(labelWithString: "●")
    private let statusTitle = NSTextField(labelWithString: "Ready")
    private let statusDetail = NSTextField(wrappingLabelWithString: "Checking the built-in display…")
    private let primaryButton = NSButton(title: "Turn Physical Display Off", target: nil, action: nil)
    private let testButton = NSButton(title: "Test for 10 Seconds", target: nil, action: nil)
    private let enforceSwitch = NSSwitch()
    private let restoreSwitch = NSSwitch()
    private let awakeSwitch = NSSwitch()
    private let diagnosticsLabel = NSTextField(wrappingLabelWithString: "")
    private let hotkeyStatusLabel = NSTextField(labelWithString: "⌃⌥⌘B")

    private var isGuarded: Bool { guardState?.active == true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        UserDefaults.standard.register(defaults: [
            "enforceZero": true,
            "restoreOnExit": true,
            "keepAwake": true,
            "lastVisibleBrightness": 0.5
        ])

        recoverStaleStateIfNeeded()
        buildWindow()
        buildStatusItem()
        configureHotkey()
        refreshCapability()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if isGuarded { restoreDisplay(silent: true) }
        hotkey?.unregister()
        stopCaffeinate()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        window.orderOut(nil)
        return false
    }

    private func recoverStaleStateIfNeeded() {
        guard let stale = StateStore.load(), stale.active else { return }
        let parentAlive = kill(pid_t(stale.parentPID), 0) == 0
        if !parentAlive && stale.restoreOnExit {
            _ = BrightnessController.shared.set(stale.restoreBrightness, display: stale.displayID)
            StateStore.markInactive()
        }
    }

    private func configureHotkey() {
        hotkey = GlobalHotkey { [weak self] in self?.toggleGuard() }
        let ok = hotkey.register()
        hotkeyStatusLabel.stringValue = ok ? "⌃⌥⌘B" : "Unavailable — shortcut is already in use"
        hotkeyStatusLabel.textColor = ok ? .secondaryLabelColor : .systemOrange
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "PanelGuard"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.delegate = self
        window.minSize = NSSize(width: 560, height: 540)

        let background = NSVisualEffectView()
        background.material = .windowBackground
        background.blendingMode = .behindWindow
        background.state = .active
        background.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = background

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 16
        root.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 30),
            root.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -30),
            root.topAnchor.constraint(equalTo: background.topAnchor, constant: 54),
            root.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -26)
        ])

        let title = NSTextField(labelWithString: "PanelGuard")
        title.font = .systemFont(ofSize: 30, weight: .bold)
        let subtitle = NSTextField(wrappingLabelWithString: "Turn off the iMac’s physical backlight while keeping the desktop alive for remote access.")
        subtitle.font = .systemFont(ofSize: 14)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 2

        root.addArrangedSubview(title)
        root.addArrangedSubview(subtitle)
        root.setCustomSpacing(22, after: subtitle)

        let statusCard = makeCard()
        let statusStack = NSStackView()
        statusStack.orientation = .horizontal
        statusStack.alignment = .centerY
        statusStack.spacing = 14
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(statusStack)
        pin(statusStack, to: statusCard, inset: 18)

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "display", accessibilityDescription: "Display")
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        icon.contentTintColor = .labelColor
        icon.setContentHuggingPriority(.required, for: .horizontal)

        statusDot.font = .systemFont(ofSize: 16, weight: .bold)
        statusDot.textColor = .systemGreen
        statusDot.setContentHuggingPriority(.required, for: .horizontal)

        let statusText = NSStackView()
        statusText.orientation = .vertical
        statusText.alignment = .leading
        statusText.spacing = 3
        statusTitle.font = .systemFont(ofSize: 16, weight: .semibold)
        statusDetail.font = .systemFont(ofSize: 12)
        statusDetail.textColor = .secondaryLabelColor
        statusText.addArrangedSubview(statusTitle)
        statusText.addArrangedSubview(statusDetail)

        statusStack.addArrangedSubview(icon)
        statusStack.addArrangedSubview(statusText)
        statusStack.addArrangedSubview(NSView())
        statusStack.addArrangedSubview(statusDot)
        root.addArrangedSubview(statusCard)
        statusCard.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        statusCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 92).isActive = true

        primaryButton.target = self
        primaryButton.action = #selector(primaryAction)
        primaryButton.bezelStyle = .rounded
        primaryButton.controlSize = .large
        primaryButton.font = .systemFont(ofSize: 15, weight: .semibold)
        primaryButton.bezelColor = .controlAccentColor
        primaryButton.contentTintColor = .white
        root.addArrangedSubview(primaryButton)
        primaryButton.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        primaryButton.heightAnchor.constraint(equalToConstant: 48).isActive = true

        testButton.target = self
        testButton.action = #selector(testAction)
        testButton.bezelStyle = .rounded
        root.addArrangedSubview(testButton)
        testButton.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let safetyCard = makeCard()
        let safetyStack = NSStackView()
        safetyStack.orientation = .vertical
        safetyStack.alignment = .leading
        safetyStack.spacing = 12
        safetyStack.translatesAutoresizingMaskIntoConstraints = false
        safetyCard.addSubview(safetyStack)
        pin(safetyStack, to: safetyCard, inset: 16)

        let safetyTitle = NSTextField(labelWithString: "Safety")
        safetyTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        safetyStack.addArrangedSubview(safetyTitle)

        enforceSwitch.state = UserDefaults.standard.bool(forKey: "enforceZero") ? .on : .off
        restoreSwitch.state = UserDefaults.standard.bool(forKey: "restoreOnExit") ? .on : .off
        awakeSwitch.state = UserDefaults.standard.bool(forKey: "keepAwake") ? .on : .off
        for toggle in [enforceSwitch, restoreSwitch, awakeSwitch] {
            toggle.target = self
            toggle.action = #selector(safetySettingChanged)
        }
        safetyStack.addArrangedSubview(settingRow(title: "Keep backlight off if brightness keys are pressed", control: enforceSwitch))
        safetyStack.addArrangedSubview(settingRow(title: "Restore brightness if PanelGuard closes unexpectedly", control: restoreSwitch))
        safetyStack.addArrangedSubview(settingRow(title: "Keep the Mac awake while guarded", control: awakeSwitch))
        root.addArrangedSubview(safetyCard)
        safetyCard.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let recoveryRow = NSStackView()
        recoveryRow.orientation = .horizontal
        recoveryRow.alignment = .centerY
        recoveryRow.spacing = 10
        let recoveryText = NSTextField(labelWithString: "Emergency restore shortcut")
        recoveryText.font = .systemFont(ofSize: 12, weight: .medium)
        hotkeyStatusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        recoveryRow.addArrangedSubview(recoveryText)
        recoveryRow.addArrangedSubview(NSView())
        recoveryRow.addArrangedSubview(hotkeyStatusLabel)
        root.addArrangedSubview(recoveryRow)
        recoveryRow.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        diagnosticsLabel.font = .monospacedSystemFont(ofSize: 10.5, weight: .regular)
        diagnosticsLabel.textColor = .tertiaryLabelColor
        diagnosticsLabel.maximumNumberOfLines = 3
        root.addArrangedSubview(diagnosticsLabel)

        let footer = NSTextField(labelWithString: "Local-only • No network access • Ventura 13+")
        footer.font = .systemFont(ofSize: 10.5)
        footer.textColor = .tertiaryLabelColor
        root.addArrangedSubview(footer)
    }

    private func makeCard() -> NSVisualEffectView {
        let card = NSVisualEffectView()
        card.material = .contentBackground
        card.blendingMode = .withinWindow
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }

    private func pin(_ view: NSView, to container: NSView, inset: CGFloat) {
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: inset),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset)
        ])
    }

    private func settingRow(title: String, control: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12.5)
        row.addArrangedSubview(label)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(control)
        row.widthAnchor.constraint(equalToConstant: 520).isActive = true
        return row
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "display", accessibilityDescription: "PanelGuard")
        let menu = NSMenu()
        let show = NSMenuItem(title: "Show PanelGuard", action: #selector(showWindow), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        let toggle = NSMenuItem(title: "Turn Physical Display Off", action: #selector(primaryAction), keyEquivalent: "")
        toggle.target = self
        toggle.tag = 1001
        menu.addItem(toggle)
        let test = NSMenuItem(title: "Test for 10 Seconds", action: #selector(testAction), keyEquivalent: "")
        test.target = self
        menu.addItem(test)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit PanelGuard", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        if isGuarded { restoreDisplay(silent: true) }
        NSApp.terminate(nil)
    }

    @objc private func primaryAction() { toggleGuard() }

    @objc private func testAction() {
        guard !isGuarded else { return }
        activateGuard(autoRestoreAfter: 10)
    }

    @objc private func safetySettingChanged() {
        let enforce = enforceSwitch.state == .on
        let restore = restoreSwitch.state == .on
        let awake = awakeSwitch.state == .on
        UserDefaults.standard.set(enforce, forKey: "enforceZero")
        UserDefaults.standard.set(restore, forKey: "restoreOnExit")
        UserDefaults.standard.set(awake, forKey: "keepAwake")

        if var state = guardState, state.active {
            state.enforceZero = enforce
            state.restoreOnExit = restore
            guardState = state
            try? StateStore.save(state)
            if awake { startCaffeinate() } else { stopCaffeinate() }
        }
    }

    fileprivate func toggleGuard() {
        if isGuarded { restoreDisplay() }
        else { activateGuard(autoRestoreAfter: nil) }
    }

    private func activateGuard(autoRestoreAfter: TimeInterval?) {
        let controller = BrightnessController.shared
        guard controller.apiAvailable, let display = controller.builtInDisplay() else {
            showError("Built-in display control is unavailable", detail: "PanelGuard could not find a controllable built-in Apple display.")
            return
        }
        guard let current = controller.get(display) else {
            showError("Couldn’t read display brightness", detail: "No changes were made. Restart PanelGuard and try again.")
            return
        }

        let stored = Float(UserDefaults.standard.double(forKey: "lastVisibleBrightness"))
        let restoreValue = current > 0.015 ? current : max(stored, 0.5)
        if current > 0.015 { UserDefaults.standard.set(Double(current), forKey: "lastVisibleBrightness") }

        let autoDate = autoRestoreAfter.map { Date().timeIntervalSince1970 + $0 }
        let state = GuardState(
            active: true,
            displayID: display,
            restoreBrightness: restoreValue,
            enforceZero: enforceSwitch.state == .on,
            restoreOnExit: restoreSwitch.state == .on,
            autoRestoreAt: autoDate,
            parentPID: getpid()
        )

        do { try StateStore.save(state) }
        catch {
            showError("Couldn’t create the safety state", detail: "PanelGuard refused to turn the display off because crash recovery could not be prepared.")
            return
        }

        guardState = state
        startWatchdog()
        guard guardState?.active == true else { return }
        if awakeSwitch.state == .on { startCaffeinate() }

        guard controller.set(0, display: display) else {
            StateStore.markInactive()
            guardState = nil
            stopCaffeinate()
            showError("Couldn’t turn the backlight off", detail: "The display rejected the brightness command. No persistent changes were made.")
            refreshCapability()
            return
        }

        if let delay = autoRestoreAfter {
            testTimer?.invalidate()
            testTimer = Timer.scheduledTimer(withTimeInterval: delay + 0.2, repeats: false) { [weak self] _ in
                self?.synchronizeAfterWatchdogRestore()
            }
        }
        updateUI()
    }

    private func restoreDisplay(silent: Bool = false) {
        testTimer?.invalidate()
        testTimer = nil
        guard let state = guardState ?? StateStore.load(), state.active else {
            guardState = nil
            updateUI()
            return
        }
        let ok = BrightnessController.shared.set(state.restoreBrightness, display: state.displayID)
        var inactive = state
        inactive.active = false
        guardState = inactive
        try? StateStore.save(inactive)
        stopCaffeinate()
        if ok { UserDefaults.standard.set(Double(state.restoreBrightness), forKey: "lastVisibleBrightness") }
        updateUI()
        if !ok && !silent {
            showError("Brightness restore needs attention", detail: "PanelGuard could not restore the saved brightness automatically. Try the iMac brightness keys.")
        }
    }

    private func synchronizeAfterWatchdogRestore() {
        guard let diskState = StateStore.load() else { return }
        if !diskState.active {
            guardState = diskState
            stopCaffeinate()
            updateUI()
        } else {
            restoreDisplay()
        }
    }

    private func startWatchdog() {
        if let watchdog, watchdog.isRunning { return }
        guard let executable = Bundle.main.executableURL else { return }
        let process = Process()
        process.executableURL = executable
        process.arguments = ["--watchdog", String(getpid()), StateStore.stateURL.path]
        do {
            try process.run()
            watchdog = process
        } catch {
            if let state = guardState {
                _ = BrightnessController.shared.set(state.restoreBrightness, display: state.displayID)
                StateStore.markInactive()
                guardState = nil
            }
            showError("Safety watchdog couldn’t start", detail: "PanelGuard kept the display on rather than operating without crash recovery.")
        }
    }

    private func startCaffeinate() {
        if let caffeinate, caffeinate.isRunning { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = ["-d", "-i", "-s", "-w", String(getpid())]
        do { try process.run(); caffeinate = process } catch { caffeinate = nil }
    }

    private func stopCaffeinate() {
        if let caffeinate, caffeinate.isRunning { caffeinate.terminate() }
        caffeinate = nil
    }

    private func refreshCapability() {
        let controller = BrightnessController.shared
        let display = controller.builtInDisplay()
        let brightness = display.flatMap { controller.get($0) }
        if let brightness, brightness > 0.015 {
            UserDefaults.standard.set(Double(brightness), forKey: "lastVisibleBrightness")
        }
        diagnosticsLabel.stringValue = "DisplayServices: \(controller.apiAvailable ? "ready" : "unavailable")   Built-in display: \(display.map { String(format: "0x%08X", $0) } ?? "not found")   Brightness: \(brightness.map { String(format: "%.3f", $0) } ?? "n/a")"
        primaryButton.isEnabled = controller.apiAvailable && display != nil && brightness != nil
        testButton.isEnabled = primaryButton.isEnabled && !isGuarded
        updateUI()
    }

    private func updateUI() {
        let controller = BrightnessController.shared
        let display = guardState.map { CGDirectDisplayID($0.displayID) } ?? controller.builtInDisplay()
        let current = display.flatMap { controller.get($0) }

        if isGuarded {
            let testing = guardState?.autoRestoreAt != nil
            statusDot.textColor = .systemIndigo
            statusTitle.stringValue = testing ? "Safe test in progress" : "Physical display off"
            statusDetail.stringValue = testing ? "The backlight will restore automatically after 10 seconds." : "Hardware brightness is held at zero while the desktop remains available remotely."
            primaryButton.title = "Restore Physical Display"
            primaryButton.bezelColor = .systemGray
            testButton.isEnabled = false
            statusItem.button?.image = NSImage(systemSymbolName: "display.slash", accessibilityDescription: "PanelGuard active")
            statusItem.menu?.item(withTag: 1001)?.title = "Restore Physical Display"
        } else {
            statusDot.textColor = .systemGreen
            statusTitle.stringValue = controller.apiAvailable && display != nil ? "Ready" : "Display control unavailable"
            statusDetail.stringValue = controller.apiAvailable && display != nil ? "The iMac display is visible. Remote access is unaffected." : "PanelGuard could not confirm control of the built-in display."
            primaryButton.title = "Turn Physical Display Off"
            primaryButton.bezelColor = .controlAccentColor
            testButton.isEnabled = primaryButton.isEnabled
            statusItem.button?.image = NSImage(systemSymbolName: "display", accessibilityDescription: "PanelGuard")
            statusItem.menu?.item(withTag: 1001)?.title = "Turn Physical Display Off"
        }

        if let display {
            diagnosticsLabel.stringValue = "DisplayServices: \(controller.apiAvailable ? "ready" : "unavailable")   Built-in display: \(String(format: "0x%08X", display))   Brightness: \(current.map { String(format: "%.3f", $0) } ?? "n/a")"
        }
    }

    private func showError(_ title: String, detail: String) {
        guard window != nil else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }
}

private func runWatchdog(arguments: [String]) -> Int32 {
    guard arguments.count >= 4,
          let parentValue = Int32(arguments[2]) else { return 64 }
    let parent = pid_t(parentValue)
    let url = URL(fileURLWithPath: arguments[3])
    let controller = BrightnessController.shared

    while true {
        guard var state = StateStore.load(from: url) else { return 0 }
        guard state.active else { return 0 }

        let now = Date().timeIntervalSince1970
        if let deadline = state.autoRestoreAt, now >= deadline {
            _ = controller.set(state.restoreBrightness, display: state.displayID)
            state.active = false
            try? StateStore.save(state, to: url)
            return 0
        }

        errno = 0
        let parentCheck = kill(parent, 0)
        let parentGone = parentCheck != 0 && errno == ESRCH
        if parentGone {
            if state.restoreOnExit {
                _ = controller.set(state.restoreBrightness, display: state.displayID)
            }
            state.active = false
            try? StateStore.save(state, to: url)
            return 0
        }

        if state.enforceZero,
           let current = controller.get(state.displayID),
           current > 0.002 {
            _ = controller.set(0, display: state.displayID)
        }
        usleep(300_000)
    }
}

private func runSelfTest() -> Int32 {
    let controller = BrightnessController.shared
    print("PanelGuard \(appVersion)")
    print("DisplayServices symbols: \(controller.apiAvailable ? "OK" : "FAIL")")
    if let display = controller.builtInDisplay() {
        print(String(format: "Built-in display: 0x%08X", display))
        if let brightness = controller.get(display) { print(String(format: "Brightness read: %.3f", brightness)) }
    } else {
        print("Built-in display: none (expected on many CI runners)")
    }
    return controller.apiAvailable ? 0 : 2
}

let arguments = CommandLine.arguments
if arguments.contains("--version") {
    print(appVersion)
    exit(0)
}
if arguments.contains("--self-test") {
    exit(runSelfTest())
}
if arguments.count > 1, arguments[1] == "--watchdog" {
    exit(runWatchdog(arguments: arguments))
}

let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
