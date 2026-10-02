import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Darwin
import Foundation

private let appVersion = "1.2.0"
private let panelGuardVendorID: UInt32 = 0x5047
private let panelGuardProductID: UInt32 = 0x0120
private let stateDirectoryName = "PanelGuard"
private let stateFileName = "guard-state-v3.json"

private var virtualHostDisplayHandle: UnsafeMutableRawPointer?

private struct VirtualHostInfo: Codable {
    var displayID: UInt32
    var pid: Int32
}

private struct GuardState: Codable {
    var active: Bool
    var physicalDisplayID: UInt32
    var restoreBrightness: Float
    var virtualDisplayID: UInt32
    var virtualHostPID: Int32
    var enforceDisconnect: Bool
    var restoreOnExit: Bool
    var autoRestoreAt: TimeInterval?
    var parentPID: Int32
}

private enum StateStore {
    static var directoryURL: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return base.appendingPathComponent(stateDirectoryName, isDirectory: true)
    }

    static var stateURL: URL {
        directoryURL.appendingPathComponent(stateFileName)
    }

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

private final class BrightnessController {
    static let shared = BrightnessController()

    typealias GetBrightness =
        @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias SetBrightness =
        @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let getter: GetBrightness?
    private let setter: SetBrightness?

    private init() {
        let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_NOW | RTLD_LOCAL
        )

        if let handle,
           let symbol = dlsym(handle, "DisplayServicesGetBrightness") {
            getter = unsafeBitCast(symbol, to: GetBrightness.self)
        } else {
            getter = nil
        }

        if let handle,
           let symbol = dlsym(handle, "DisplayServicesSetBrightness") {
            setter = unsafeBitCast(symbol, to: SetBrightness.self)
        } else {
            setter = nil
        }
    }

    var apiAvailable: Bool {
        getter != nil && setter != nil
    }

    func builtInDisplay() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success,
              count > 0 else {
            return nil
        }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else {
            return nil
        }

        return ids.prefix(Int(count)).first {
            CGDisplayIsBuiltin($0) != 0
        }
    }

    func get(_ display: CGDirectDisplayID) -> Float? {
        guard let getter else { return nil }
        var value: Float = 0
        return getter(display, &value) == 0 ? value : nil
    }

    @discardableResult
    func set(_ value: Float, display: CGDirectDisplayID) -> Bool {
        guard let setter else { return false }
        return setter(display, min(max(value, 0), 1)) == 0
    }
}

private final class DisplayConnectionController {
    static let shared = DisplayConnectionController()

    typealias CoreDisplaySetUserEnabled =
        @convention(c) (CGDirectDisplayID, Bool) -> Int32
    typealias SkyLightConfigureEnabled =
        @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError

    private let coreSetEnabled: CoreDisplaySetUserEnabled?
    private let skySetEnabled: SkyLightConfigureEnabled?

    private init() {
        let core = dlopen(
            "/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay",
            RTLD_LAZY
        )

        if let core,
           let symbol = dlsym(core, "CoreDisplay_Display_SetUserEnabled") {
            coreSetEnabled = unsafeBitCast(
                symbol,
                to: CoreDisplaySetUserEnabled.self
            )
        } else {
            coreSetEnabled = nil
        }

        let sky = dlopen(
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
            RTLD_LAZY
        )

        if let sky,
           let symbol =
            dlsym(sky, "SLSConfigureDisplayEnabled")
            ?? dlsym(sky, "CGSConfigureDisplayEnabled") {
            skySetEnabled = unsafeBitCast(
                symbol,
                to: SkyLightConfigureEnabled.self
            )
        } else {
            skySetEnabled = nil
        }
    }

    var apiAvailable: Bool {
        coreSetEnabled != nil || skySetEnabled != nil
    }

    var methodDescription: String {
        if coreSetEnabled != nil {
            return "CoreDisplay"
        }
        if skySetEnabled != nil {
            return "SkyLight"
        }
        return "Unavailable"
    }

    private func stateMatches(
        _ enabled: Bool,
        display: CGDirectDisplayID
    ) -> Bool {
        if enabled {
            return CGDisplayIsOnline(display) != 0
                && CGDisplayIsActive(display) != 0
        }

        return CGDisplayIsOnline(display) == 0
            || CGDisplayIsActive(display) == 0
    }

    private func waitForState(
        _ enabled: Bool,
        display: CGDirectDisplayID,
        timeout: TimeInterval = 1.8
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            if stateMatches(enabled, display: display) {
                return true
            }
            usleep(100_000)
        } while Date() < deadline

        return stateMatches(enabled, display: display)
    }

    @discardableResult
    func setEnabled(
        _ enabled: Bool,
        display: CGDirectDisplayID
    ) -> Bool {
        if stateMatches(enabled, display: display) {
            return true
        }

        if let coreSetEnabled {
            if coreSetEnabled(display, enabled) == 0,
               waitForState(enabled, display: display) {
                return true
            }
        }

        if let skySetEnabled {
            var config: CGDisplayConfigRef?

            if CGBeginDisplayConfiguration(&config) == .success,
               let config {
                let result = skySetEnabled(config, display, enabled)

                if result == .success {
                    if CGCompleteDisplayConfiguration(
                        config,
                        .forAppOnly
                    ) == .success,
                       waitForState(enabled, display: display) {
                        return true
                    }
                } else {
                    CGCancelDisplayConfiguration(config)
                }
            }
        }

        return stateMatches(enabled, display: display)
    }

    func restoreWithRetries(
        display: CGDirectDisplayID,
        attempts: Int = 6
    ) -> Bool {
        for attempt in 0..<attempts {
            if setEnabled(true, display: display) {
                return true
            }

            if attempt + 1 < attempts {
                usleep(350_000)
            }
        }

        return false
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
        let hotKeyID = EventHotKeyID(
            signature: signature,
            id: identifier
        )

        let result = RegisterEventHotKey(
            UInt32(kVK_ANSI_B),
            UInt32(cmdKey | optionKey | controlKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard result == noErr,
              let ref else {
            return false
        }

        hotKeyRef = ref

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let opaque = Unmanaged.passUnretained(self).toOpaque()

        let callback: EventHandlerUPP = {
            _, event, userData in

            guard let event,
                  let userData else {
                return OSStatus(eventNotHandledErr)
            }

            let manager =
                Unmanaged<GlobalHotkey>
                .fromOpaque(userData)
                .takeUnretainedValue()

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

            DispatchQueue.main.async {
                manager.action()
            }

            return noErr
        }

        guard InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            opaque,
            &eventHandler
        ) == noErr else {
            unregister()
            return false
        }

        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }

        hotKeyRef = nil
        eventHandler = nil
    }

    deinit {
        unregister()
    }
}

private final class AppDelegate:
    NSObject,
    NSApplicationDelegate,
    NSWindowDelegate
{
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var hotkey: GlobalHotkey!

    private var caffeinate: Process?
    private var watchdog: Process?
    private var virtualHost: Process?
    private var virtualInfoURL: URL?
    private var pollTimer: Timer?

    private var guardState: GuardState?
    private var virtualDisplayID: CGDirectDisplayID = 0

    private let statusDot = NSTextField(labelWithString: "●")
    private let statusTitle = NSTextField(labelWithString: "Ready")
    private let statusDetail = NSTextField(
        wrappingLabelWithString: "Checking display control…"
    )

    private let primaryButton = NSButton(
        title: "Turn Physical Display Off",
        target: nil,
        action: nil
    )

    private let testButton = NSButton(
        title: "Test for 10 Seconds",
        target: nil,
        action: nil
    )

    private let enforceSwitch = NSSwitch()
    private let restoreSwitch = NSSwitch()
    private let awakeSwitch = NSSwitch()

    private let diagnostics = NSTextField(
        wrappingLabelWithString: ""
    )

    private let hotkeyLabel = NSTextField(
        labelWithString: "⌃⌥⌘B"
    )

    private var isGuarded: Bool {
        guardState?.active == true
    }

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        NSApp.setActivationPolicy(.regular)

        UserDefaults.standard.register(defaults: [
            "enforceDisconnect": true,
            "restoreOnExit": true,
            "keepAwake": true,
            "lastVisibleBrightness": 0.5
        ])

        recoverStaleState()
        buildWindow()
        buildStatusItem()
        configureHotkey()
        refreshCapability()

        pollTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            self?.pollGuardState()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(
        _ notification: Notification
    ) {
        if isGuarded {
            restoreDisplay(silent: true)
        }

        if !isGuarded {
            stopVirtualHost()
            stopCaffeinate()
            stopWatchdog()
        }

        hotkey?.unregister()
        pollTimer?.invalidate()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        window.orderOut(nil)
        return false
    }

    private func recoverStaleState() {
        guard var state = StateStore.load(),
              state.active else {
            return
        }

        errno = 0
        let parentAlive =
            kill(pid_t(state.parentPID), 0) == 0
            || errno != ESRCH

        guard !parentAlive else {
            return
        }

        let restored =
            DisplayConnectionController.shared.restoreWithRetries(
                display: state.physicalDisplayID
            )

        if restored {
            usleep(350_000)

            _ = BrightnessController.shared.set(
                state.restoreBrightness,
                display: state.physicalDisplayID
            )

            if state.virtualHostPID > 0 {
                _ = kill(pid_t(state.virtualHostPID), SIGTERM)
            }

            state.active = false
            try? StateStore.save(state)
        }
    }

    private func configureHotkey() {
        hotkey = GlobalHotkey { [weak self] in
            self?.toggleGuard()
        }

        let ok = hotkey.register()

        hotkeyLabel.stringValue =
            ok
            ? "⌃⌥⌘B"
            : "Unavailable — shortcut already in use"

        hotkeyLabel.textColor =
            ok
            ? .secondaryLabelColor
            : .systemOrange
    }

    private func pollGuardState() {
        guard isGuarded else {
            return
        }

        if let diskState = StateStore.load(),
           !diskState.active {
            guardState = diskState
            cleanupVirtualHostReference()
            stopCaffeinate()
            updateUI()
            return
        }

        guard let state = guardState else {
            return
        }

        errno = 0
        let helperAlive =
            kill(pid_t(state.virtualHostPID), 0) == 0
            || errno != ESRCH

        let virtualAlive =
            state.virtualDisplayID != 0
            && CGDisplayIsOnline(state.virtualDisplayID) != 0
            && CGDisplayIsActive(state.virtualDisplayID) != 0

        if !helperAlive || !virtualAlive {
            emergencyRestoreBecauseVirtualDisplayWasLost()
        }
    }

    private func emergencyRestoreBecauseVirtualDisplayWasLost() {
        guard var state = guardState,
              state.active else {
            return
        }

        let restored =
            DisplayConnectionController.shared.restoreWithRetries(
                display: state.physicalDisplayID
            )

        if restored {
            usleep(350_000)

            _ = BrightnessController.shared.set(
                state.restoreBrightness,
                display: state.physicalDisplayID
            )

            state.active = false
            try? StateStore.save(state)
            guardState = state

            cleanupVirtualHostReference()
            stopCaffeinate()
            stopWatchdog()
            updateUI()

            showError(
                "Remote display ended unexpectedly",
                "PanelGuard restored the physical iMac display automatically."
            )
        }
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 650,
                height: 610
            ),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        window.title = "PanelGuard"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.delegate = self
        window.minSize = NSSize(
            width: 590,
            height: 570
        )

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
            root.leadingAnchor.constraint(
                equalTo: background.leadingAnchor,
                constant: 30
            ),
            root.trailingAnchor.constraint(
                equalTo: background.trailingAnchor,
                constant: -30
            ),
            root.topAnchor.constraint(
                equalTo: background.topAnchor,
                constant: 54
            ),
            root.bottomAnchor.constraint(
                lessThanOrEqualTo: background.bottomAnchor,
                constant: -24
            )
        ])

        let title = NSTextField(
            labelWithString: "PanelGuard"
        )

        title.font = .systemFont(
            ofSize: 30,
            weight: .bold
        )

        let subtitle = NSTextField(
            wrappingLabelWithString:
                "Private remote access without leaving ghost displays behind. A dedicated helper owns one temporary Retina framebuffer and exits completely when the physical iMac display returns."
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
        icon.image = NSImage(
            systemSymbolName: "display.2",
            accessibilityDescription: "Displays"
        )
        icon.symbolConfiguration =
            NSImage.SymbolConfiguration(
                pointSize: 30,
                weight: .medium
            )
        icon.contentTintColor = .labelColor

        let statusText = NSStackView()
        statusText.orientation = .vertical
        statusText.alignment = .leading
        statusText.spacing = 3

        statusTitle.font = .systemFont(
            ofSize: 16,
            weight: .semibold
        )

        statusDetail.font = .systemFont(ofSize: 12)
        statusDetail.textColor = .secondaryLabelColor
        statusDetail.maximumNumberOfLines = 3

        statusText.addArrangedSubview(statusTitle)
        statusText.addArrangedSubview(statusDetail)

        statusDot.font = .systemFont(
            ofSize: 16,
            weight: .bold
        )
        statusDot.textColor = .systemGreen

        statusRow.addArrangedSubview(icon)
        statusRow.addArrangedSubview(statusText)
        statusRow.addArrangedSubview(NSView())
        statusRow.addArrangedSubview(statusDot)

        root.addArrangedSubview(statusCard)

        statusCard.widthAnchor.constraint(
            equalTo: root.widthAnchor
        ).isActive = true

        statusCard.heightAnchor.constraint(
            greaterThanOrEqualToConstant: 100
        ).isActive = true

        primaryButton.target = self
        primaryButton.action = #selector(primaryAction)
        primaryButton.bezelStyle = .rounded
        primaryButton.controlSize = .large
        primaryButton.font = .systemFont(
            ofSize: 15,
            weight: .semibold
        )
        primaryButton.bezelColor = .controlAccentColor
        primaryButton.contentTintColor = .white

        root.addArrangedSubview(primaryButton)

        primaryButton.widthAnchor.constraint(
            equalTo: root.widthAnchor
        ).isActive = true

        primaryButton.heightAnchor.constraint(
            equalToConstant: 48
        ).isActive = true

        testButton.target = self
        testButton.action = #selector(testAction)
        testButton.bezelStyle = .rounded

        root.addArrangedSubview(testButton)

        testButton.widthAnchor.constraint(
            equalTo: root.widthAnchor
        ).isActive = true

        let safetyCard = makeCard()

        let safetyStack = NSStackView()
        safetyStack.orientation = .vertical
        safetyStack.alignment = .leading
        safetyStack.spacing = 12
        safetyStack.translatesAutoresizingMaskIntoConstraints = false

        safetyCard.addSubview(safetyStack)
        pin(safetyStack, to: safetyCard, inset: 16)

        let safetyTitle = NSTextField(
            labelWithString: "Safety & Reliability"
        )

        safetyTitle.font = .systemFont(
            ofSize: 13,
            weight: .semibold
        )

        safetyStack.addArrangedSubview(safetyTitle)

        enforceSwitch.state =
            UserDefaults.standard.bool(
                forKey: "enforceDisconnect"
            )
            ? .on
            : .off

        restoreSwitch.state =
            UserDefaults.standard.bool(
                forKey: "restoreOnExit"
            )
            ? .on
            : .off

        awakeSwitch.state =
            UserDefaults.standard.bool(
                forKey: "keepAwake"
            )
            ? .on
            : .off

        for toggle in [
            enforceSwitch,
            restoreSwitch,
            awakeSwitch
        ] {
            toggle.target = self
            toggle.action = #selector(settingsChanged)
        }

        safetyStack.addArrangedSubview(
            settingRow(
                "Re-disconnect the physical panel if macOS brings it back",
                enforceSwitch
            )
        )

        safetyStack.addArrangedSubview(
            settingRow(
                "Restore the physical display if PanelGuard closes unexpectedly",
                restoreSwitch
            )
        )

        safetyStack.addArrangedSubview(
            settingRow(
                "Keep the Mac and remote framebuffer awake while guarded",
                awakeSwitch
            )
        )

        root.addArrangedSubview(safetyCard)

        safetyCard.widthAnchor.constraint(
            equalTo: root.widthAnchor
        ).isActive = true

        let recovery = NSStackView()
        recovery.orientation = .horizontal
        recovery.alignment = .centerY

        let recoveryLabel = NSTextField(
            labelWithString: "Emergency restore shortcut"
        )

        recoveryLabel.font = .systemFont(
            ofSize: 12,
            weight: .medium
        )

        hotkeyLabel.font =
            .monospacedSystemFont(
                ofSize: 12,
                weight: .semibold
            )

        recovery.addArrangedSubview(recoveryLabel)
        recovery.addArrangedSubview(NSView())
        recovery.addArrangedSubview(hotkeyLabel)

        root.addArrangedSubview(recovery)

        recovery.widthAnchor.constraint(
            equalTo: root.widthAnchor
        ).isActive = true

        diagnostics.font =
            .monospacedSystemFont(
                ofSize: 10.5,
                weight: .regular
            )

        diagnostics.textColor = .tertiaryLabelColor
        diagnostics.maximumNumberOfLines = 5

        root.addArrangedSubview(diagnostics)

        let footer = NSTextField(
            labelWithString:
                "Local-only • No network access • Intel macOS Ventura 13+ • PanelGuard \(appVersion)"
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

    private func pin(
        _ view: NSView,
        to container: NSView,
        inset: CGFloat
    ) {
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(
                equalTo: container.leadingAnchor,
                constant: inset
            ),
            view.trailingAnchor.constraint(
                equalTo: container.trailingAnchor,
                constant: -inset
            ),
            view.topAnchor.constraint(
                equalTo: container.topAnchor,
                constant: inset
            ),
            view.bottomAnchor.constraint(
                equalTo: container.bottomAnchor,
                constant: -inset
            )
        ])
    }

    private func settingRow(
        _ title: String,
        _ control: NSView
    ) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY

        let label = NSTextField(
            labelWithString: title
        )

        label.font = .systemFont(ofSize: 12.5)

        row.addArrangedSubview(label)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(control)

        row.widthAnchor.constraint(
            equalToConstant: 545
        ).isActive = true

        return row
    }

    private func buildStatusItem() {
        statusItem =
            NSStatusBar.system.statusItem(
                withLength: NSStatusItem.squareLength
            )

        statusItem.button?.image =
            NSImage(
                systemSymbolName: "display.2",
                accessibilityDescription: "PanelGuard"
            )

        let menu = NSMenu()

        let show = NSMenuItem(
            title: "Show PanelGuard",
            action: #selector(showWindow),
            keyEquivalent: ""
        )

        show.target = self
        menu.addItem(show)

        let toggle = NSMenuItem(
            title: "Turn Physical Display Off",
            action: #selector(primaryAction),
            keyEquivalent: ""
        )

        toggle.target = self
        toggle.tag = 1001
        menu.addItem(toggle)

        let test = NSMenuItem(
            title: "Test for 10 Seconds",
            action: #selector(testAction),
            keyEquivalent: ""
        )

        test.target = self
        test.tag = 1002
        menu.addItem(test)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit PanelGuard",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )

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

            if isGuarded {
                return
            }
        }

        NSApp.terminate(nil)
    }

    @objc private func primaryAction() {
        toggleGuard()
    }

    @objc private func testAction() {
        if !isGuarded {
            activateGuard(autoRestoreAfter: 10)
        }
    }

    @objc private func settingsChanged() {
        let enforce =
            enforceSwitch.state == .on

        let restore =
            restoreSwitch.state == .on

        let awake =
            awakeSwitch.state == .on

        UserDefaults.standard.set(
            enforce,
            forKey: "enforceDisconnect"
        )

        UserDefaults.standard.set(
            restore,
            forKey: "restoreOnExit"
        )

        UserDefaults.standard.set(
            awake,
            forKey: "keepAwake"
        )

        if var state = guardState,
           state.active {
            state.enforceDisconnect = enforce
            state.restoreOnExit = restore
            guardState = state

            try? StateStore.save(state)

            if awake {
                startCaffeinate()
            } else {
                stopCaffeinate()
            }
        }
    }

    fileprivate func toggleGuard() {
        if isGuarded {
            restoreDisplay()
        } else {
            activateGuard(autoRestoreAfter: nil)
        }
    }

    private func existingPanelGuardVirtualDisplays()
        -> [CGDirectDisplayID]
    {
        var count: UInt32 = 0

        guard CGGetOnlineDisplayList(
            0,
            nil,
            &count
        ) == .success,
              count > 0 else {
            return []
        }

        var ids =
            [CGDirectDisplayID](
                repeating: 0,
                count: Int(count)
            )

        guard CGGetOnlineDisplayList(
            count,
            &ids,
            &count
        ) == .success else {
            return []
        }

        return ids.prefix(Int(count)).filter {
            CGDisplayVendorNumber($0)
                == panelGuardVendorID
        }
    }

    private func screen(
        for displayID: CGDirectDisplayID
    ) -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let number =
                screen.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")
                ] as? NSNumber else {
                return false
            }

            return number.uint32Value == displayID
        }
    }

    private func copyWallpaper(
        from physicalID: CGDirectDisplayID,
        to virtualID: CGDirectDisplayID
    ) {
        let deadline =
            Date().addingTimeInterval(2)

        var physicalScreen: NSScreen?
        var virtualScreen: NSScreen?

        repeat {
            physicalScreen =
                screen(for: physicalID)

            virtualScreen =
                screen(for: virtualID)

            if physicalScreen != nil,
               virtualScreen != nil {
                break
            }

            RunLoop.main.run(
                until:
                    Date().addingTimeInterval(0.05)
            )
        } while Date() < deadline

        guard let physicalScreen,
              let virtualScreen else {
            return
        }

        let workspace = NSWorkspace.shared

        guard let imageURL =
            workspace.desktopImageURL(
                for: physicalScreen
            ) else {
            return
        }

        let options =
            workspace.desktopImageOptions(
                for: physicalScreen
            )
            ?? [:]

        try? workspace.setDesktopImageURL(
            imageURL,
            for: virtualScreen,
            options: options
        )
    }

    private func startVirtualHost(
        for physicalID: CGDirectDisplayID
    ) -> Bool {
        guard virtualHost == nil,
              PGVirtualDisplayAPISupported() != 0,
              let mode =
                CGDisplayCopyDisplayMode(
                    physicalID
                ),
              let executable =
                Bundle.main.executableURL else {
            return false
        }

        let infoURL =
            StateStore.directoryURL
            .appendingPathComponent(
                "virtual-host-\(UUID().uuidString).json"
            )

        try? FileManager.default.createDirectory(
            at: StateStore.directoryURL,
            withIntermediateDirectories: true
        )

        try? FileManager.default.removeItem(
            at: infoURL
        )

        let refreshRate =
            mode.refreshRate > 1
            ? mode.refreshRate
            : 60.0

        let serial =
            arc4random()
            | 1

        let process = Process()
        process.executableURL = executable
        process.arguments = [
            "--virtual-host",
            infoURL.path,
            String(mode.pixelWidth),
            String(mode.pixelHeight),
            String(refreshRate),
            String(serial)
        ]

        process.standardOutput =
            FileHandle.nullDevice

        process.standardError =
            FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return false
        }

        virtualHost = process
        virtualInfoURL = infoURL

        let deadline =
            Date().addingTimeInterval(4)

        repeat {
            guard process.isRunning else {
                stopVirtualHost()
                return false
            }

            if let data =
                try? Data(contentsOf: infoURL),
               let info =
                try? JSONDecoder().decode(
                    VirtualHostInfo.self,
                    from: data
                ),
               info.displayID != 0,
               info.pid == process.processIdentifier,
               CGDisplayIsOnline(
                    info.displayID
               ) != 0,
               CGDisplayIsActive(
                    info.displayID
               ) != 0,
               CGDisplayIsInMirrorSet(
                    info.displayID
               ) == 0 {

                virtualDisplayID =
                    info.displayID

                copyWallpaper(
                    from: physicalID,
                    to: info.displayID
                )

                return true
            }

            RunLoop.main.run(
                until:
                    Date().addingTimeInterval(0.05)
            )
        } while Date() < deadline

        stopVirtualHost()
        return false
    }

    private func stopVirtualHost() {
        let oldID = virtualDisplayID

        if let process = virtualHost,
           process.isRunning {
            process.terminate()

            let deadline =
                Date().addingTimeInterval(2)

            while process.isRunning,
                  Date() < deadline {
                RunLoop.main.run(
                    until:
                        Date().addingTimeInterval(0.05)
                )
            }

            if process.isRunning {
                _ = kill(
                    pid_t(process.processIdentifier),
                    SIGKILL
                )
            }
        }

        virtualHost = nil

        if let virtualInfoURL {
            try? FileManager.default.removeItem(
                at: virtualInfoURL
            )
        }

        virtualInfoURL = nil
        virtualDisplayID = 0

        if oldID != 0 {
            let deadline =
                Date().addingTimeInterval(2)

            while CGDisplayIsOnline(oldID) != 0,
                  Date() < deadline {
                RunLoop.main.run(
                    until:
                        Date().addingTimeInterval(0.05)
                )
            }
        }
    }

    private func cleanupVirtualHostReference() {
        if let process = virtualHost,
           process.isRunning {
            process.terminate()
        }

        virtualHost = nil

        if let virtualInfoURL {
            try? FileManager.default.removeItem(
                at: virtualInfoURL
            )
        }

        virtualInfoURL = nil
        virtualDisplayID = 0
    }

    private func activateGuard(
        autoRestoreAfter: TimeInterval?
    ) {
        let brightness =
            BrightnessController.shared

        let connection =
            DisplayConnectionController.shared

        guard connection.apiAvailable else {
            showError(
                "Physical display disconnect is unavailable",
                "PanelGuard could not load the macOS display-disconnect API."
            )
            return
        }

        guard PGVirtualDisplayAPISupported()
                != 0 else {
            showError(
                "Virtual display support is unavailable",
                "PanelGuard could not create the temporary remote framebuffer."
            )
            return
        }

        let leftovers =
            existingPanelGuardVirtualDisplays()

        if !leftovers.isEmpty {
            showError(
                "Old PanelGuard virtual displays are still active",
                "Fully quit the older PanelGuard process once, then reopen PanelGuard 1.2. This release will not create another display while stale PanelGuard displays exist."
            )
            return
        }

        guard let physical =
                brightness.builtInDisplay(),
              let currentBrightness =
                brightness.get(physical) else {
            showError(
                "Built-in iMac display not found",
                "PanelGuard could not identify and read the built-in Apple display."
            )
            return
        }

        let stored =
            Float(
                UserDefaults.standard.double(
                    forKey: "lastVisibleBrightness"
                )
            )

        let restoreBrightness =
            currentBrightness > 0.015
            ? currentBrightness
            : max(stored, 0.5)

        if currentBrightness > 0.015 {
            UserDefaults.standard.set(
                Double(currentBrightness),
                forKey:
                    "lastVisibleBrightness"
            )
        }

        statusTitle.stringValue =
            "Preparing private display…"

        statusDetail.stringValue =
            "Starting one isolated Retina framebuffer and verifying that it is not mirrored."

        primaryButton.isEnabled = false
        testButton.isEnabled = false

        guard startVirtualHost(
            for: physical
        ),
              let host = virtualHost,
              virtualDisplayID != 0 else {
            refreshCapability()

            showError(
                "Couldn’t create an isolated remote display",
                "PanelGuard kept the physical iMac display on. No display changes were committed."
            )
            return
        }

        let state = GuardState(
            active: true,
            physicalDisplayID: physical,
            restoreBrightness:
                restoreBrightness,
            virtualDisplayID:
                virtualDisplayID,
            virtualHostPID:
                host.processIdentifier,
            enforceDisconnect:
                enforceSwitch.state == .on,
            restoreOnExit:
                restoreSwitch.state == .on,
            autoRestoreAt:
                autoRestoreAfter.map {
                    Date().timeIntervalSince1970
                    + $0
                },
            parentPID: getpid()
        )

        do {
            try StateStore.save(state)
        } catch {
            stopVirtualHost()
            refreshCapability()

            showError(
                "Couldn’t arm crash recovery",
                "PanelGuard refused to disconnect the display because the safety state could not be saved."
            )
            return
        }

        guardState = state
        startWatchdog()

        if awakeSwitch.state == .on {
            startCaffeinate()
        }

        _ = brightness.set(
            0,
            display: physical
        )

        guard connection.setEnabled(
                false,
                display: physical
              ),
              CGDisplayIsActive(
                virtualDisplayID
              ) != 0,
              CGDisplayIsInMirrorSet(
                virtualDisplayID
              ) == 0 else {
            rollbackFailedActivation(
                state: state
            )
            return
        }

        updateUI()
    }

    private func rollbackFailedActivation(
        state: GuardState
    ) {
        stopWatchdog()

        let restored =
            DisplayConnectionController.shared
            .restoreWithRetries(
                display: state.physicalDisplayID
            )

        if restored {
            usleep(350_000)

            _ = BrightnessController.shared.set(
                state.restoreBrightness,
                display: state.physicalDisplayID
            )

            var inactive = state
            inactive.active = false

            guardState = inactive
            try? StateStore.save(inactive)

            stopVirtualHost()
            stopCaffeinate()
            refreshCapability()

            showError(
                "The private-display transition was rejected",
                "PanelGuard detected mirroring, a lost virtual framebuffer, or an incomplete physical-display disconnect and restored the iMac instead."
            )
        } else {
            guardState = state
            startWatchdog()
            updateUI()

            showError(
                "Physical display restore needs attention",
                "PanelGuard kept the remote framebuffer alive because the physical display could not yet be restored. Use ⌃⌥⌘B to retry."
            )
        }
    }

    private func restoreDisplay(
        silent: Bool = false
    ) {
        guard var state =
                guardState
                ?? StateStore.load(),
              state.active else {
            guardState = nil
            stopVirtualHost()
            updateUI()
            return
        }

        stopWatchdog()

        let restored =
            DisplayConnectionController.shared
            .restoreWithRetries(
                display: state.physicalDisplayID
            )

        if restored {
            usleep(350_000)

            _ = BrightnessController.shared.set(
                state.restoreBrightness,
                display: state.physicalDisplayID
            )

            UserDefaults.standard.set(
                Double(
                    state.restoreBrightness
                ),
                forKey:
                    "lastVisibleBrightness"
            )

            state.active = false
            guardState = state

            try? StateStore.save(state)

            stopVirtualHost()
            stopCaffeinate()
            updateUI()
        } else {
            guardState = state

            try? StateStore.save(state)
            startWatchdog()
            updateUI()

            if !silent {
                showError(
                    "Physical display restore needs attention",
                    "PanelGuard kept the temporary remote display alive. Try ⌃⌥⌘B again; if macOS still refuses the restore, log out or restart."
                )
            }
        }
    }

    private func startWatchdog() {
        if let watchdog,
           watchdog.isRunning {
            return
        }

        guard let executable =
                Bundle.main.executableURL else {
            return
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = [
            "--watchdog",
            String(getpid()),
            StateStore.stateURL.path
        ]

        process.standardOutput =
            FileHandle.nullDevice

        process.standardError =
            FileHandle.nullDevice

        do {
            try process.run()
            watchdog = process
        } catch {
            watchdog = nil

            if let state =
                guardState {
                rollbackFailedActivation(
                    state: state
                )
            }
        }
    }

    private func stopWatchdog() {
        if let watchdog,
           watchdog.isRunning {
            watchdog.terminate()
        }

        watchdog = nil
    }

    private func startCaffeinate() {
        if let caffeinate,
           caffeinate.isRunning {
            return
        }

        let process = Process()
        process.executableURL =
            URL(
                fileURLWithPath:
                    "/usr/bin/caffeinate"
            )

        process.arguments = [
            "-d",
            "-i",
            "-s",
            "-w",
            String(getpid())
        ]

        do {
            try process.run()
            caffeinate = process
        } catch {
            caffeinate = nil
        }
    }

    private func stopCaffeinate() {
        if let caffeinate,
           caffeinate.isRunning {
            caffeinate.terminate()
        }

        caffeinate = nil
    }

    private func refreshCapability() {
        let brightness =
            BrightnessController.shared

        let connection =
            DisplayConnectionController.shared

        let physical =
            brightness.builtInDisplay()

        let virtualReady =
            PGVirtualDisplayAPISupported()
            != 0

        let staleCount =
            existingPanelGuardVirtualDisplays()
            .count

        if let physical,
           let value =
            brightness.get(physical),
           value > 0.015 {
            UserDefaults.standard.set(
                Double(value),
                forKey:
                    "lastVisibleBrightness"
            )
        }

        diagnostics.stringValue =
            "Disconnect: \(connection.methodDescription)   Virtual API: \(virtualReady ? "ready" : "unavailable")\n"
            + "Built-in: \(physical.map { String(format: "0x%08X", $0) } ?? "not found")   "
            + "Old PanelGuard displays: \(staleCount)\n"
            + "Session model: one helper process → one temporary display → process exit cleanup"

        primaryButton.isEnabled =
            connection.apiAvailable
            && virtualReady
            && physical != nil
            && brightness.apiAvailable
            && staleCount == 0

        testButton.isEnabled =
            primaryButton.isEnabled
            && !isGuarded

        updateUI()
    }

    private func updateUI() {
        if isGuarded {
            let testing =
                guardState?.autoRestoreAt
                != nil

            statusDot.textColor =
                .systemIndigo

            statusTitle.stringValue =
                testing
                ? "Safe test in progress"
                : "Physical iMac display disconnected"

            statusDetail.stringValue =
                testing
                ? "One isolated remote display is active. The physical panel will restore automatically after 10 seconds."
                : "One isolated remote framebuffer is active; no additional PanelGuard displays will be created in this session."

            primaryButton.title =
                "Restore Physical Display"

            primaryButton.bezelColor =
                .systemGray

            primaryButton.isEnabled = true
            testButton.isEnabled = false

            statusItem.button?.image =
                NSImage(
                    systemSymbolName:
                        "display.slash",
                    accessibilityDescription:
                        "PanelGuard active"
                )

            statusItem.menu?
                .item(withTag: 1001)?
                .title =
                "Restore Physical Display"

            statusItem.menu?
                .item(withTag: 1002)?
                .isEnabled = false

            diagnostics.stringValue =
                "Physical: \(String(format: "0x%08X", guardState?.physicalDisplayID ?? 0)) active=\((guardState.map { CGDisplayIsActive($0.physicalDisplayID) != 0 } ?? false) ? "YES" : "NO")\n"
                + "Virtual: \(String(format: "0x%08X", guardState?.virtualDisplayID ?? 0)) active=\((guardState.map { CGDisplayIsActive($0.virtualDisplayID) != 0 } ?? false) ? "YES" : "NO") "
                + "mirrored=\((guardState.map { CGDisplayIsInMirrorSet($0.virtualDisplayID) != 0 } ?? false) ? "YES" : "NO")\n"
                + "Virtual helper PID: \(guardState?.virtualHostPID ?? 0)"
        } else {
            statusDot.textColor =
                .systemGreen

            statusTitle.stringValue =
                "Ready"

            statusDetail.stringValue =
                "No PanelGuard virtual display is active. A fresh isolated framebuffer will exist only while the physical screen is guarded."

            primaryButton.title =
                "Turn Physical Display Off"

            primaryButton.bezelColor =
                .controlAccentColor

            statusItem.button?.image =
                NSImage(
                    systemSymbolName:
                        "display.2",
                    accessibilityDescription:
                        "PanelGuard"
                )

            statusItem.menu?
                .item(withTag: 1001)?
                .title =
                "Turn Physical Display Off"

            statusItem.menu?
                .item(withTag: 1002)?
                .isEnabled =
                primaryButton.isEnabled
        }
    }

    private func showError(
        _ title: String,
        _ detail: String
    ) {
        guard window != nil else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }
}

private func restorePhysicalFromWatchdog(
    state: GuardState
) -> Bool {
    let restored =
        DisplayConnectionController.shared
        .restoreWithRetries(
            display: state.physicalDisplayID
        )

    if restored {
        usleep(350_000)

        _ = BrightnessController.shared.set(
            state.restoreBrightness,
            display: state.physicalDisplayID
        )
    }

    return restored
}

private func runWatchdog(
    _ arguments: [String]
) -> Int32 {
    guard arguments.count >= 4,
          let parentValue =
            Int32(arguments[2]) else {
        return 64
    }

    let parentPID =
        pid_t(parentValue)

    let stateURL =
        URL(fileURLWithPath: arguments[3])

    while true {
        guard var state =
                StateStore.load(
                    from: stateURL
                ),
              state.active else {
            return 0
        }

        errno = 0

        let parentGone =
            kill(parentPID, 0) != 0
            && errno == ESRCH

        errno = 0

        let virtualHostGone =
            state.virtualHostPID <= 0
            || (
                kill(
                    pid_t(state.virtualHostPID),
                    0
                ) != 0
                && errno == ESRCH
            )

        let timedOut =
            state.autoRestoreAt.map {
                Date().timeIntervalSince1970
                    >= $0
            }
            ?? false

        if timedOut
            || virtualHostGone
            || (
                parentGone
                && state.restoreOnExit
            ) {

            if restorePhysicalFromWatchdog(
                state: state
            ) {
                if state.virtualHostPID > 0 {
                    _ = kill(
                        pid_t(
                            state.virtualHostPID
                        ),
                        SIGTERM
                    )
                }

                state.active = false

                try? StateStore.save(
                    state,
                    to: stateURL
                )

                return 0
            }

            usleep(500_000)
            continue
        }

        if parentGone
            && !state.restoreOnExit {
            return 0
        }

        if state.enforceDisconnect,
           CGDisplayIsActive(
                state.physicalDisplayID
           ) != 0 {
            _ = BrightnessController.shared.set(
                0,
                display:
                    state.physicalDisplayID
            )

            _ = DisplayConnectionController.shared
                .setEnabled(
                    false,
                    display:
                        state.physicalDisplayID
                )
        }

        usleep(300_000)
    }
}

private func runVirtualHost(
    _ arguments: [String]
) -> Int32 {
    guard arguments.count >= 7,
          let pixelWidth =
            UInt32(arguments[3]),
          let pixelHeight =
            UInt32(arguments[4]),
          let refreshRate =
            Double(arguments[5]),
          let serial =
            UInt32(arguments[6]) else {
        return 64
    }

    let infoURL =
        URL(fileURLWithPath: arguments[2])

    var displayID: UInt32 = 0

    guard let handle =
        PGCreateVirtualDisplay(
            pixelWidth,
            pixelHeight,
            refreshRate,
            panelGuardVendorID,
            panelGuardProductID,
            serial,
            &displayID
        ),
          displayID != 0 else {
        return 2
    }

    virtualHostDisplayHandle = handle

    let info = VirtualHostInfo(
        displayID: displayID,
        pid: getpid()
    )

    do {
        try FileManager.default.createDirectory(
            at:
                infoURL
                .deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try JSONEncoder()
            .encode(info)
            .write(
                to: infoURL,
                options: .atomic
            )
    } catch {
        return 3
    }

    RunLoop.main.run()

    return 0
}

private func runSelfTest() -> Int32 {
    let brightness =
        BrightnessController.shared

    let connection =
        DisplayConnectionController.shared

    let virtualReady =
        PGVirtualDisplayAPISupported()
        != 0

    print("PanelGuard \(appVersion)")
    print(
        "DisplayServices symbols: "
        + (
            brightness.apiAvailable
            ? "OK"
            : "FAIL"
        )
    )

    print(
        "Display disconnect API: "
        + connection.methodDescription
    )

    print(
        "CGVirtualDisplay classes: "
        + (
            virtualReady
            ? "OK"
            : "FAIL"
        )
    )

    if let display =
        brightness.builtInDisplay() {
        print(
            String(
                format:
                    "Built-in display: 0x%08X",
                display
            )
        )

        if let mode =
            CGDisplayCopyDisplayMode(
                display
            ) {
            print(
                "Current pixel mode: "
                + "\(mode.pixelWidth)x\(mode.pixelHeight)"
            )
        }

        if let value =
            brightness.get(display) {
            print(
                String(
                    format:
                        "Brightness read: %.3f",
                    value
                )
            )
        }
    } else {
        print("Built-in display: none")
    }

    return brightness.apiAvailable
        && connection.apiAvailable
        && virtualReady
        ? 0
        : 2
}

let arguments = CommandLine.arguments

if arguments.contains("--version") {
    print(appVersion)
    exit(0)
}

if arguments.contains("--self-test") {
    exit(runSelfTest())
}

if arguments.count > 1,
   arguments[1] == "--watchdog" {
    exit(runWatchdog(arguments))
}

if arguments.count > 1,
   arguments[1] == "--virtual-host" {
    exit(runVirtualHost(arguments))
}

let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
