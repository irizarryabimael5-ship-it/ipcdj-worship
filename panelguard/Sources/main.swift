import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Darwin
import Foundation

private let appVersion = "1.4.0"
private let stateDirectoryName = "PanelGuard"
private let stateFileName = "guard-state-v5.json"

private struct RawSnapshot: Codable {
    var brightness: Int32
    var brightnessMin: Int32
    var brightnessMax: Int32
    var linearSupported: Bool
    var linearBrightness: Int32
    var linearMin: Int32
    var linearMax: Int32
}

private struct GuardState: Codable {
    var active: Bool
    var displayID: UInt32
    var snapshot: RawSnapshot
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
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
    }
}

private enum RawBacklight {
    static func builtInDisplay() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return nil }
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    static func snapshot(_ display: CGDirectDisplayID) -> RawSnapshot? {
        guard PGRawBacklightAPISupported(display) != 0 else { return nil }

        var value: Int32 = 0
        var minValue: Int32 = 0
        var maxValue: Int32 = 0
        guard PGRawBrightnessGet(display, &value, &minValue, &maxValue) == 0 else { return nil }

        var linearValue: Int32 = 0
        var linearMin: Int32 = 0
        var linearMax: Int32 = 0
        let linearOK = PGLinearBrightnessGet(
            display,
            &linearValue,
            &linearMin,
            &linearMax
        ) == 0

        return RawSnapshot(
            brightness: value,
            brightnessMin: minValue,
            brightnessMax: maxValue,
            linearSupported: linearOK,
            linearBrightness: linearValue,
            linearMin: linearMin,
            linearMax: linearMax
        )
    }

    @discardableResult
    static func setHardwareZero(_ display: CGDirectDisplayID) -> Bool {
        // Deliberately bypasses the normalized/user brightness API.
        // Apple's own backlight driver uses raw integer 0 for its off state.
        let result = PGRawBrightnessSet(display, 0)
        if result == 0 { _ = PGCommitDisplayParameters(display) }
        return result == 0
    }

    @discardableResult
    static func restore(_ state: GuardState) -> Bool {
        var ok = PGRawBrightnessSet(state.displayID, state.snapshot.brightness) == 0

        if state.snapshot.linearSupported {
            let linearOK = PGLinearBrightnessSet(
                state.displayID,
                state.snapshot.linearBrightness
            ) == 0
            ok = ok && linearOK
        }

        _ = PGCommitDisplayParameters(state.displayID)
        _ = PGWakeLogicalDisplay()
        return ok
    }

    static func topologySignature() -> String {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success else { return "error" }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return "error" }

        return ids.prefix(Int(count))
            .sorted()
            .map { id in
                let r = CGDisplayBounds(id)
                return "\(id):\(Int(r.origin.x)),\(Int(r.origin.y)),\(Int(r.width)),\(Int(r.height))"
            }
            .joined(separator: "|")
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
        guard RegisterEventHotKey(
            UInt32(kVK_ANSI_B),
            UInt32(cmdKey | optionKey | controlKey),
            id,
            GetApplicationEventTarget(),
            0,
            &ref
        ) == noErr, let ref else { return false }
        hotKeyRef = ref

        var type = EventTypeSpec(
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

        guard InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &type,
            opaque,
            &eventHandler
        ) == noErr else {
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
    private var watchdog: Process?
    private var caffeinate: Process?
    private var pollTimer: Timer?
    private var guardState: GuardState?

    private let statusDot = NSTextField(labelWithString: "●")
    private let statusTitle = NSTextField(labelWithString: "Ready")
    private let statusDetail = NSTextField(wrappingLabelWithString: "Checking raw hardware backlight control…")
    private let primaryButton = NSButton(title: "Turn Physical Backlight Off", target: nil, action: nil)
    private let testButton = NSButton(title: "Test Raw Backlight for 10 Seconds", target: nil, action: nil)
    private let diagnostics = NSTextField(wrappingLabelWithString: "")
    private let hotkeyLabel = NSTextField(labelWithString: "⌃⌥⌘B")

    private var isGuarded: Bool { guardState?.active == true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        recoverStaleState()
        buildWindow()
        buildStatusItem()
        configureHotkey()
        refreshCapability()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            self?.syncState()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if isGuarded { restoreDisplay(silent: true) }
        stopWatchdog()
        stopCaffeinate()
        hotkey?.unregister()
        pollTimer?.invalidate()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        window.orderOut(nil)
        return false
    }

    private func recoverStaleState() {
        guard var state = StateStore.load(), state.active else { return }

        errno = 0
        let parentAlive = kill(pid_t(state.parentPID), 0) == 0 || errno != ESRCH
        guard !parentAlive else { return }

        _ = RawBacklight.restore(state)
        state.active = false
        try? StateStore.save(state)
    }

    private func configureHotkey() {
        hotkey = GlobalHotkey { [weak self] in self?.toggleGuard() }
        let ok = hotkey.register()
        hotkeyLabel.stringValue = ok ? "⌃⌥⌘B" : "Unavailable"
        hotkeyLabel.textColor = ok ? .secondaryLabelColor : .systemOrange
    }

    private func syncState() {
        guard isGuarded, let disk = StateStore.load(), !disk.active else { return }
        guardState = disk
        stopWatchdog()
        stopCaffeinate()
        updateUI()
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 575),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "PanelGuard"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.delegate = self
        window.minSize = NSSize(width: 590, height: 535)

        let background = NSVisualEffectView()
        background.material = .windowBackground
        background.blendingMode = .behindWindow
        background.state = .active
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
            root.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -24)
        ])

        let title = NSTextField(labelWithString: "PanelGuard")
        title.font = .systemFont(ofSize: 30, weight: .bold)

        let subtitle = NSTextField(
            wrappingLabelWithString:
                "Backlight-only remote privacy. The iMac display stays logically awake and drawable; PanelGuard changes only the raw hardware backlight value."
        )
        subtitle.font = .systemFont(ofSize: 14)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 3

        root.addArrangedSubview(title)
        root.addArrangedSubview(subtitle)
        root.setCustomSpacing(22, after: subtitle)

        let statusCard = makeCard()
        let statusRow = NSStackView()
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 14
        statusRow.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(statusRow)
        pin(statusRow, to: statusCard, inset: 18)

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "display", accessibilityDescription: "Display")
        icon.symbolConfiguration = .init(pointSize: 30, weight: .medium)
        icon.contentTintColor = .labelColor

        let statusText = NSStackView()
        statusText.orientation = .vertical
        statusText.alignment = .leading
        statusText.spacing = 3
        statusTitle.font = .systemFont(ofSize: 16, weight: .semibold)
        statusDetail.font = .systemFont(ofSize: 12)
        statusDetail.textColor = .secondaryLabelColor
        statusDetail.maximumNumberOfLines = 3
        statusText.addArrangedSubview(statusTitle)
        statusText.addArrangedSubview(statusDetail)

        statusDot.font = .systemFont(ofSize: 16, weight: .bold)
        statusDot.textColor = .systemGreen

        statusRow.addArrangedSubview(icon)
        statusRow.addArrangedSubview(statusText)
        statusRow.addArrangedSubview(NSView())
        statusRow.addArrangedSubview(statusDot)

        root.addArrangedSubview(statusCard)
        statusCard.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        statusCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true

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
        let safety = NSStackView()
        safety.orientation = .vertical
        safety.alignment = .leading
        safety.spacing = 9
        safety.translatesAutoresizingMaskIntoConstraints = false
        safetyCard.addSubview(safety)
        pin(safety, to: safetyCard, inset: 16)

        let safetyTitle = NSTextField(labelWithString: "Safety")
        safetyTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        safety.addArrangedSubview(safetyTitle)

        let line1 = NSTextField(wrappingLabelWithString:
            "• The original display ID, resolution, Spaces, wallpaper, and monitor arrangement are never changed.")
        let line2 = NSTextField(wrappingLabelWithString:
            "• The watchdog keeps the logical display awake for RustDesk and restores the exact raw brightness after the test.")
        let line3 = NSTextField(wrappingLabelWithString:
            "• Brightness Up (F2), ⌃⌥⌘B, or the menu-bar Restore can release PanelGuard.")
        for label in [line1, line2, line3] {
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            label.maximumNumberOfLines = 2
            safety.addArrangedSubview(label)
        }

        root.addArrangedSubview(safetyCard)
        safetyCard.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let recovery = NSStackView()
        recovery.orientation = .horizontal
        recovery.alignment = .centerY
        let recoveryText = NSTextField(labelWithString: "Emergency shortcut")
        recoveryText.font = .systemFont(ofSize: 12, weight: .medium)
        hotkeyLabel.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        recovery.addArrangedSubview(recoveryText)
        recovery.addArrangedSubview(NSView())
        recovery.addArrangedSubview(hotkeyLabel)
        root.addArrangedSubview(recovery)
        recovery.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        diagnostics.font = .monospacedSystemFont(ofSize: 10.5, weight: .regular)
        diagnostics.textColor = .tertiaryLabelColor
        diagnostics.maximumNumberOfLines = 5
        root.addArrangedSubview(diagnostics)

        let footer = NSTextField(
            labelWithString:
                "No virtual display • No display sleep • No disconnect • PanelGuard \(appVersion)"
        )
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

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "display", accessibilityDescription: "PanelGuard")

        let menu = NSMenu()
        let show = NSMenuItem(title: "Show PanelGuard", action: #selector(showWindow), keyEquivalent: "")
        show.target = self
        menu.addItem(show)

        let toggle = NSMenuItem(title: "Turn Physical Backlight Off", action: #selector(primaryAction), keyEquivalent: "")
        toggle.target = self
        toggle.tag = 1001
        menu.addItem(toggle)

        let test = NSMenuItem(title: "Test Raw Backlight for 10 Seconds", action: #selector(testAction), keyEquivalent: "")
        test.target = self
        test.tag = 1002
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
        if isGuarded {
            restoreDisplay(silent: false)
            if isGuarded { return }
        }
        NSApp.terminate(nil)
    }

    @objc private func primaryAction() { toggleGuard() }

    @objc private func testAction() {
        if !isGuarded { activateGuard(autoRestoreAfter: 10) }
    }

    fileprivate func toggleGuard() {
        isGuarded ? restoreDisplay() : activateGuard(autoRestoreAfter: nil)
    }

    private func activateGuard(autoRestoreAfter: TimeInterval?) {
        guard let display = RawBacklight.builtInDisplay(),
              let snapshot = RawBacklight.snapshot(display) else {
            showError(
                "Raw backlight control is unavailable",
                "PanelGuard could not read the built-in display's IOKit brightness parameters."
            )
            return
        }

        guard CGDisplayIsAsleep(display) == 0 else {
            _ = PGWakeLogicalDisplay()
            showError(
                "The iMac display is logically asleep",
                "Wake it once and run the test again. PanelGuard 1.4 requires the framebuffer to remain awake for RustDesk."
            )
            return
        }

        let topologyBefore = RawBacklight.topologySignature()
        let state = GuardState(
            active: true,
            displayID: display,
            snapshot: snapshot,
            autoRestoreAt: autoRestoreAfter.map { Date().timeIntervalSince1970 + $0 },
            parentPID: getpid()
        )

        do {
            try StateStore.save(state)
        } catch {
            showError(
                "Couldn’t arm crash recovery",
                "No hardware values were changed."
            )
            return
        }

        guardState = state
        startWatchdog()
        startCaffeinate()

        guard RawBacklight.setHardwareZero(display) else {
            rollback(state, message: "The display rejected raw backlight zero.")
            return
        }

        usleep(250_000)

        let topologyAfter = RawBacklight.topologySignature()
        guard topologyBefore == topologyAfter else {
            rollback(
                state,
                message: "macOS changed the display topology unexpectedly, so PanelGuard restored immediately."
            )
            return
        }

        guard CGDisplayIsAsleep(display) == 0 else {
            _ = PGWakeLogicalDisplay()
            rollback(
                state,
                message: "The display entered logical sleep, so PanelGuard restored it rather than freezing RustDesk."
            )
            return
        }

        updateUI()
    }

    private func rollback(_ state: GuardState, message: String) {
        var inactive = state
        inactive.active = false
        try? StateStore.save(inactive)
        guardState = inactive
        stopWatchdog()
        stopCaffeinate()
        _ = RawBacklight.restore(state)
        updateUI()
        showError("Raw backlight test aborted", message)
    }

    private func restoreDisplay(silent: Bool = false) {
        guard var state = guardState ?? StateStore.load(), state.active else {
            guardState = nil
            updateUI()
            return
        }

        state.active = false
        try? StateStore.save(state)
        guardState = state
        stopWatchdog()
        stopCaffeinate()

        let ok = RawBacklight.restore(state)
        updateUI()

        if !ok && !silent {
            showError(
                "Brightness restore needs attention",
                "PanelGuard released control. Press Brightness Up once if the physical panel has not returned."
            )
        }
    }

    private func startWatchdog() {
        if let watchdog, watchdog.isRunning { return }
        guard let executable = Bundle.main.executableURL else { return }

        let process = Process()
        process.executableURL = executable
        process.arguments = ["--watchdog", String(getpid()), StateStore.stateURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            watchdog = process
        } catch {
            watchdog = nil
            if let state = guardState { rollback(state, message: "The independent safety watchdog could not start.") }
        }
    }

    private func stopWatchdog() {
        if let watchdog, watchdog.isRunning { watchdog.terminate() }
        watchdog = nil
    }

    private func startCaffeinate() {
        if let caffeinate, caffeinate.isRunning { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        // Here -d is intentional: the framebuffer must remain logically awake.
        process.arguments = ["-d", "-i", "-s", "-w", String(getpid())]
        do {
            try process.run()
            caffeinate = process
        } catch {
            caffeinate = nil
        }
    }

    private func stopCaffeinate() {
        if let caffeinate, caffeinate.isRunning { caffeinate.terminate() }
        caffeinate = nil
    }

    private func refreshCapability() {
        let display = RawBacklight.builtInDisplay()
        let snapshot = display.flatMap { RawBacklight.snapshot($0) }

        if let display, let snapshot {
            diagnostics.stringValue =
                "Built-in: \(String(format: "0x%08X", display))   logical asleep=\(CGDisplayIsAsleep(display) != 0 ? "YES" : "NO")\n" +
                "raw brightness: value=\(snapshot.brightness) min=\(snapshot.brightnessMin) max=\(snapshot.brightnessMax)\n" +
                "linear brightness: " +
                (snapshot.linearSupported
                    ? "value=\(snapshot.linearBrightness) min=\(snapshot.linearMin) max=\(snapshot.linearMax)"
                    : "unsupported") +
                "\nTopology-changing APIs in 1.4: NONE"
        } else {
            diagnostics.stringValue =
                "Raw IOKit brightness parameters unavailable on the built-in display."
        }

        primaryButton.isEnabled = display != nil && snapshot != nil
        testButton.isEnabled = primaryButton.isEnabled && !isGuarded
        updateUI()
    }

    private func updateUI() {
        if isGuarded, let state = guardState {
            statusDot.textColor = .systemIndigo
            statusTitle.stringValue = state.autoRestoreAt != nil ? "Safe raw-backlight test" : "Physical backlight held at raw zero"
            statusDetail.stringValue =
                "The original iMac framebuffer remains awake and drawable for RustDesk. Only the hardware brightness parameter is zero."
            primaryButton.title = "Restore Physical Backlight"
            primaryButton.bezelColor = .systemGray
            primaryButton.isEnabled = true
            testButton.isEnabled = false
            statusItem.button?.image = NSImage(systemSymbolName: "display", accessibilityDescription: "PanelGuard active")
            statusItem.menu?.item(withTag: 1001)?.title = "Restore Physical Backlight"
            statusItem.menu?.item(withTag: 1002)?.isEnabled = false

            var v: Int32 = 0, mn: Int32 = 0, mx: Int32 = 0
            _ = PGRawBrightnessGet(state.displayID, &v, &mn, &mx)
            diagnostics.stringValue =
                "Display: \(String(format: "0x%08X", state.displayID))   logical asleep=\(CGDisplayIsAsleep(state.displayID) != 0 ? "YES" : "NO")\n" +
                "raw brightness now=\(v)   saved=\(state.snapshot.brightness)   range=\(mn)…\(mx)\n" +
                "Framebuffer policy: KEEP AWAKE   Topology changes: NONE"
        } else {
            statusDot.textColor = .systemGreen
            statusTitle.stringValue = "Ready"
            statusDetail.stringValue =
                "No display has been added, disconnected, or put to sleep. PanelGuard is ready for the raw-backlight test."
            primaryButton.title = "Turn Physical Backlight Off"
            primaryButton.bezelColor = .controlAccentColor
            statusItem.menu?.item(withTag: 1001)?.title = "Turn Physical Backlight Off"
            statusItem.menu?.item(withTag: 1002)?.isEnabled = primaryButton.isEnabled
        }
    }

    private func showError(_ title: String, _ detail: String) {
        guard window != nil else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }
}

private func restoreFromWatchdog(_ state: inout GuardState, url: URL) {
    state.active = false
    try? StateStore.save(state, to: url)
    _ = RawBacklight.restore(state)
}

private func runWatchdog(_ arguments: [String]) -> Int32 {
    guard arguments.count >= 4, let parentValue = Int32(arguments[2]) else { return 64 }

    let parentPID = pid_t(parentValue)
    let url = URL(fileURLWithPath: arguments[3])

    while true {
        guard var state = StateStore.load(from: url), state.active else { return 0 }

        let timedOut = state.autoRestoreAt.map {
            Date().timeIntervalSince1970 >= $0
        } ?? false

        errno = 0
        let parentGone = kill(parentPID, 0) != 0 && errno == ESRCH

        if timedOut || parentGone {
            restoreFromWatchdog(&state, url: url)
            return 0
        }

        // RustDesk must always see a drawable framebuffer.
        if CGDisplayIsAsleep(state.displayID) != 0 {
            _ = PGWakeLogicalDisplay()
            usleep(100_000)
            if state.active {
                _ = PGRawBrightnessSet(state.displayID, 0)
                _ = PGCommitDisplayParameters(state.displayID)
            }
        }

        var current: Int32 = 0
        var minValue: Int32 = 0
        var maxValue: Int32 = 0
        if PGRawBrightnessGet(
            state.displayID,
            &current,
            &minValue,
            &maxValue
        ) == 0 {
            // Physical Brightness Up is the hardware rescue.
            // Any meaningful increase above raw zero releases the guard.
            if current > max(1, minValue) {
                restoreFromWatchdog(&state, url: url)
                return 0
            }

            if current != 0 {
                _ = PGRawBrightnessSet(state.displayID, 0)
                _ = PGCommitDisplayParameters(state.displayID)
            }
        }

        usleep(80_000)
    }
}

private func runSelfTest() -> Int32 {
    print("PanelGuard \(appVersion)")

    guard let display = RawBacklight.builtInDisplay() else {
        print("Built-in display: none")
        return 2
    }

    print(String(format: "Built-in display: 0x%08X", display))
    print("Logical asleep: \(CGDisplayIsAsleep(display) != 0 ? "YES" : "NO")")
    print("Raw backlight API: \(PGRawBacklightAPISupported(display) != 0 ? "OK" : "FAIL")")

    if let snapshot = RawBacklight.snapshot(display) {
        print("Raw brightness: value=\(snapshot.brightness) min=\(snapshot.brightnessMin) max=\(snapshot.brightnessMax)")
        print(
            snapshot.linearSupported
                ? "Linear brightness: value=\(snapshot.linearBrightness) min=\(snapshot.linearMin) max=\(snapshot.linearMax)"
                : "Linear brightness: unsupported"
        )
        return 0
    }

    return 2
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
    exit(runWatchdog(arguments))
}

let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
