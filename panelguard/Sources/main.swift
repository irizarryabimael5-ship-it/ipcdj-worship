import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Darwin
import Foundation

private let appVersion = "1.3.0"
private let stateDirectoryName = "PanelGuard"
private let stateFileName = "guard-state-v4.json"

private struct GuardState: Codable {
    var active: Bool
    var displayID: UInt32
    var restoreBrightness: Float
    var holdAsleep: Bool
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
        return base.appendingPathComponent(
            stateDirectoryName,
            isDirectory: true
        )
    }

    static var stateURL: URL {
        directoryURL.appendingPathComponent(stateFileName)
    }

    static func load(from url: URL = stateURL) -> GuardState? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(
            GuardState.self,
            from: data
        )
    }

    static func save(
        _ state: GuardState,
        to url: URL = stateURL
    ) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try JSONEncoder()
            .encode(state)
            .write(to: url, options: .atomic)
    }
}

private final class BrightnessController {
    static let shared = BrightnessController()

    typealias GetBrightness =
        @convention(c) (
            CGDirectDisplayID,
            UnsafeMutablePointer<Float>
        ) -> Int32

    typealias SetBrightness =
        @convention(c) (
            CGDirectDisplayID,
            Float
        ) -> Int32

    private let getter: GetBrightness?
    private let setter: SetBrightness?

    private init() {
        let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_NOW | RTLD_LOCAL
        )

        if let handle,
           let symbol = dlsym(
                handle,
                "DisplayServicesGetBrightness"
           ) {
            getter = unsafeBitCast(
                symbol,
                to: GetBrightness.self
            )
        } else {
            getter = nil
        }

        if let handle,
           let symbol = dlsym(
                handle,
                "DisplayServicesSetBrightness"
           ) {
            setter = unsafeBitCast(
                symbol,
                to: SetBrightness.self
            )
        } else {
            setter = nil
        }
    }

    var apiAvailable: Bool {
        getter != nil && setter != nil
    }

    func builtInDisplay() -> CGDirectDisplayID? {
        var count: UInt32 = 0

        guard CGGetOnlineDisplayList(
            0,
            nil,
            &count
        ) == .success,
              count > 0 else {
            return nil
        }

        var displays = [CGDirectDisplayID](
            repeating: 0,
            count: Int(count)
        )

        guard CGGetOnlineDisplayList(
            count,
            &displays,
            &count
        ) == .success else {
            return nil
        }

        return displays
            .prefix(Int(count))
            .first {
                CGDisplayIsBuiltin($0) != 0
            }
    }

    func get(
        _ display: CGDirectDisplayID
    ) -> Float? {
        guard let getter else {
            return nil
        }

        var value: Float = 0

        return getter(
            display,
            &value
        ) == 0
            ? value
            : nil
    }

    @discardableResult
    func set(
        _ value: Float,
        display: CGDirectDisplayID
    ) -> Bool {
        guard let setter else {
            return false
        }

        return setter(
            display,
            min(max(value, 0), 1)
        ) == 0
    }
}

private enum DisplayPower {
    static var apiAvailable: Bool {
        PGDisplayPowerAPISupported() != 0
    }

    @discardableResult
    static func requestSleep() -> Bool {
        PGRequestDisplayIdle(1) == 0
    }

    @discardableResult
    static func requestWake() -> Bool {
        PGWakeDisplay() == 0
    }

    static func waitForSleep(
        _ display: CGDirectDisplayID,
        timeout: TimeInterval
    ) -> Bool {
        let deadline =
            Date().addingTimeInterval(timeout)

        repeat {
            if CGDisplayIsAsleep(display) != 0 {
                return true
            }

            RunLoop.current.run(
                until:
                    Date()
                    .addingTimeInterval(0.04)
            )
        } while Date() < deadline

        return CGDisplayIsAsleep(display) != 0
    }

    static func waitForWake(
        _ display: CGDirectDisplayID,
        timeout: TimeInterval
    ) -> Bool {
        let deadline =
            Date().addingTimeInterval(timeout)

        repeat {
            if CGDisplayIsAsleep(display) == 0 {
                return true
            }

            _ = requestWake()

            RunLoop.current.run(
                until:
                    Date()
                    .addingTimeInterval(0.08)
            )
        } while Date() < deadline

        return CGDisplayIsAsleep(display) == 0
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

        let registerStatus =
            RegisterEventHotKey(
                UInt32(kVK_ANSI_B),
                UInt32(
                    cmdKey
                    | optionKey
                    | controlKey
                ),
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )

        guard registerStatus == noErr,
              let ref else {
            return false
        }

        hotKeyRef = ref

        var eventType = EventTypeSpec(
            eventClass:
                OSType(
                    kEventClassKeyboard
                ),
            eventKind:
                UInt32(
                    kEventHotKeyPressed
                )
        )

        let opaque =
            Unmanaged
            .passUnretained(self)
            .toOpaque()

        let callback: EventHandlerUPP = {
            _, event, userData in

            guard let event,
                  let userData else {
                return OSStatus(
                    eventNotHandledErr
                )
            }

            let manager =
                Unmanaged<GlobalHotkey>
                .fromOpaque(userData)
                .takeUnretainedValue()

            var incoming =
                EventHotKeyID()

            let status =
                GetEventParameter(
                    event,
                    EventParamName(
                        kEventParamDirectObject
                    ),
                    EventParamType(
                        typeEventHotKeyID
                    ),
                    nil,
                    MemoryLayout<
                        EventHotKeyID
                    >.size,
                    nil,
                    &incoming
                )

            guard status == noErr,
                  incoming.signature
                    == manager.signature,
                  incoming.id
                    == manager.identifier else {
                return OSStatus(
                    eventNotHandledErr
                )
            }

            DispatchQueue.main.async {
                manager.action()
            }

            return noErr
        }

        let installStatus =
            InstallEventHandler(
                GetApplicationEventTarget(),
                callback,
                1,
                &eventType,
                opaque,
                &eventHandler
            )

        guard installStatus == noErr else {
            unregister()
            return false
        }

        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(
                hotKeyRef
            )
        }

        if let eventHandler {
            RemoveEventHandler(
                eventHandler
            )
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

    private var watchdog: Process?
    private var caffeinate: Process?
    private var stateTimer: Timer?

    private var guardState: GuardState?

    private let statusDot =
        NSTextField(labelWithString: "●")

    private let statusTitle =
        NSTextField(labelWithString: "Ready")

    private let statusDetail =
        NSTextField(
            wrappingLabelWithString:
                "Checking the built-in display…"
        )

    private let primaryButton =
        NSButton(
            title:
                "Put Physical Display to Sleep",
            target: nil,
            action: nil
        )

    private let testButton =
        NSButton(
            title:
                "Test for 10 Seconds",
            target: nil,
            action: nil
        )

    private let holdSwitch =
        NSSwitch()

    private let restoreSwitch =
        NSSwitch()

    private let awakeSwitch =
        NSSwitch()

    private let diagnostics =
        NSTextField(
            wrappingLabelWithString: ""
        )

    private let hotkeyLabel =
        NSTextField(
            labelWithString: "⌃⌥⌘B"
        )

    private var isGuarded: Bool {
        guardState?.active == true
    }

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        NSApp.setActivationPolicy(.regular)

        UserDefaults.standard.register(
            defaults: [
                "holdAsleep": true,
                "restoreOnExit": true,
                "keepMacAwake": true,
                "lastVisibleBrightness": 0.5
            ]
        )

        recoverStaleState()
        buildWindow()
        buildStatusItem()
        configureHotkey()
        refreshCapability()

        stateTimer =
            Timer.scheduledTimer(
                withTimeInterval: 0.4,
                repeats: true
            ) { [weak self] _ in
                self?.syncFromStateFile()
            }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(
            ignoringOtherApps: true
        )
    }

    func applicationWillTerminate(
        _ notification: Notification
    ) {
        if isGuarded {
            restoreDisplay(
                silent: true
            )
        }

        stopWatchdog()
        stopCaffeinate()
        hotkey?.unregister()
        stateTimer?.invalidate()
    }

    func windowShouldClose(
        _ sender: NSWindow
    ) -> Bool {
        window.orderOut(nil)
        return false
    }

    private func recoverStaleState() {
        guard var stale =
                StateStore.load(),
              stale.active else {
            return
        }

        errno = 0

        let parentAlive =
            kill(
                pid_t(stale.parentPID),
                0
            ) == 0
            || errno != ESRCH

        guard !parentAlive else {
            return
        }

        if stale.restoreOnExit {
            stale.active = false

            try? StateStore.save(
                stale
            )

            _ = DisplayPower.requestWake()

            _ = BrightnessController.shared
                .set(
                    stale.restoreBrightness,
                    display: stale.displayID
                )
        }
    }

    private func configureHotkey() {
        hotkey =
            GlobalHotkey {
                [weak self] in
                self?.toggleGuard()
            }

        let ok =
            hotkey.register()

        hotkeyLabel.stringValue =
            ok
            ? "⌃⌥⌘B"
            : "Unavailable"

        hotkeyLabel.textColor =
            ok
            ? .secondaryLabelColor
            : .systemOrange
    }

    private func syncFromStateFile() {
        guard let diskState =
                StateStore.load() else {
            return
        }

        if isGuarded
            && !diskState.active {
            guardState = diskState
            stopWatchdog()
            stopCaffeinate()
            updateUI()
        }
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 640,
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
        window.minSize =
            NSSize(
                width: 580,
                height: 570
            )

        let background =
            NSVisualEffectView()

        background.material =
            .windowBackground

        background.blendingMode =
            .behindWindow

        background.state =
            .active

        window.contentView = background

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 16
        root.translatesAutoresizingMaskIntoConstraints = false

        background.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(
                equalTo:
                    background.leadingAnchor,
                constant: 30
            ),
            root.trailingAnchor.constraint(
                equalTo:
                    background.trailingAnchor,
                constant: -30
            ),
            root.topAnchor.constraint(
                equalTo:
                    background.topAnchor,
                constant: 54
            ),
            root.bottomAnchor.constraint(
                lessThanOrEqualTo:
                    background.bottomAnchor,
                constant: -24
            )
        ])

        let title =
            NSTextField(
                labelWithString:
                    "PanelGuard"
            )

        title.font =
            .systemFont(
                ofSize: 30,
                weight: .bold
            )

        let subtitle =
            NSTextField(
                wrappingLabelWithString:
                    "Power down the existing iMac panel without adding, removing, mirroring, or rearranging any displays."
            )

        subtitle.font =
            .systemFont(ofSize: 14)

        subtitle.textColor =
            .secondaryLabelColor

        subtitle.maximumNumberOfLines = 3

        root.addArrangedSubview(title)
        root.addArrangedSubview(subtitle)
        root.setCustomSpacing(
            22,
            after: subtitle
        )

        let statusCard = makeCard()

        let statusRow = NSStackView()
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 14
        statusRow.translatesAutoresizingMaskIntoConstraints = false

        statusCard.addSubview(statusRow)
        pin(
            statusRow,
            to: statusCard,
            inset: 18
        )

        let icon = NSImageView()

        icon.image =
            NSImage(
                systemSymbolName:
                    "display",
                accessibilityDescription:
                    "Display"
            )

        icon.symbolConfiguration =
            NSImage.SymbolConfiguration(
                pointSize: 30,
                weight: .medium
            )

        icon.contentTintColor =
            .labelColor

        let statusText = NSStackView()
        statusText.orientation = .vertical
        statusText.alignment = .leading
        statusText.spacing = 3

        statusTitle.font =
            .systemFont(
                ofSize: 16,
                weight: .semibold
            )

        statusDetail.font =
            .systemFont(ofSize: 12)

        statusDetail.textColor =
            .secondaryLabelColor

        statusDetail.maximumNumberOfLines = 3

        statusText.addArrangedSubview(
            statusTitle
        )

        statusText.addArrangedSubview(
            statusDetail
        )

        statusDot.font =
            .systemFont(
                ofSize: 16,
                weight: .bold
            )

        statusDot.textColor =
            .systemGreen

        statusRow.addArrangedSubview(icon)
        statusRow.addArrangedSubview(
            statusText
        )
        statusRow.addArrangedSubview(
            NSView()
        )
        statusRow.addArrangedSubview(
            statusDot
        )

        root.addArrangedSubview(statusCard)

        statusCard.widthAnchor
            .constraint(
                equalTo: root.widthAnchor
            )
            .isActive = true

        statusCard.heightAnchor
            .constraint(
                greaterThanOrEqualToConstant:
                    100
            )
            .isActive = true

        primaryButton.target = self
        primaryButton.action =
            #selector(primaryAction)

        primaryButton.bezelStyle =
            .rounded

        primaryButton.controlSize =
            .large

        primaryButton.font =
            .systemFont(
                ofSize: 15,
                weight: .semibold
            )

        primaryButton.bezelColor =
            .controlAccentColor

        primaryButton.contentTintColor =
            .white

        root.addArrangedSubview(
            primaryButton
        )

        primaryButton.widthAnchor
            .constraint(
                equalTo: root.widthAnchor
            )
            .isActive = true

        primaryButton.heightAnchor
            .constraint(
                equalToConstant: 48
            )
            .isActive = true

        testButton.target = self
        testButton.action =
            #selector(testAction)

        testButton.bezelStyle =
            .rounded

        root.addArrangedSubview(
            testButton
        )

        testButton.widthAnchor
            .constraint(
                equalTo: root.widthAnchor
            )
            .isActive = true

        let safetyCard = makeCard()

        let safety = NSStackView()
        safety.orientation = .vertical
        safety.alignment = .leading
        safety.spacing = 12
        safety.translatesAutoresizingMaskIntoConstraints = false

        safetyCard.addSubview(safety)

        pin(
            safety,
            to: safetyCard,
            inset: 16
        )

        let safetyTitle =
            NSTextField(
                labelWithString:
                    "Safety & Reliability"
            )

        safetyTitle.font =
            .systemFont(
                ofSize: 13,
                weight: .semibold
            )

        safety.addArrangedSubview(
            safetyTitle
        )

        holdSwitch.state =
            UserDefaults.standard.bool(
                forKey: "holdAsleep"
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
                forKey: "keepMacAwake"
            )
            ? .on
            : .off

        for toggle in [
            holdSwitch,
            restoreSwitch,
            awakeSwitch
        ] {
            toggle.target = self
            toggle.action =
                #selector(settingsChanged)
        }

        safety.addArrangedSubview(
            settingRow(
                "Keep the panel asleep if remote input wakes it",
                holdSwitch
            )
        )

        safety.addArrangedSubview(
            settingRow(
                "Wake and restore brightness if PanelGuard closes",
                restoreSwitch
            )
        )

        safety.addArrangedSubview(
            settingRow(
                "Keep the Mac itself awake while the display sleeps",
                awakeSwitch
            )
        )

        root.addArrangedSubview(
            safetyCard
        )

        safetyCard.widthAnchor
            .constraint(
                equalTo: root.widthAnchor
            )
            .isActive = true

        let recovery = NSStackView()
        recovery.orientation = .horizontal
        recovery.alignment = .centerY

        let recoveryText =
            NSTextField(
                labelWithString:
                    "Recovery"
            )

        recoveryText.font =
            .systemFont(
                ofSize: 12,
                weight: .medium
            )

        let recoveryDetail =
            NSTextField(
                labelWithString:
                    "Brightness Up (F2) • ⌃⌥⌘B • menu-bar Restore"
            )

        recoveryDetail.font =
            .monospacedSystemFont(
                ofSize: 11.5,
                weight: .medium
            )

        recoveryDetail.textColor =
            .secondaryLabelColor

        recovery.addArrangedSubview(
            recoveryText
        )

        recovery.addArrangedSubview(
            NSView()
        )

        recovery.addArrangedSubview(
            recoveryDetail
        )

        root.addArrangedSubview(
            recovery
        )

        recovery.widthAnchor
            .constraint(
                equalTo: root.widthAnchor
            )
            .isActive = true

        diagnostics.font =
            .monospacedSystemFont(
                ofSize: 10.5,
                weight: .regular
            )

        diagnostics.textColor =
            .tertiaryLabelColor

        diagnostics.maximumNumberOfLines = 4

        root.addArrangedSubview(
            diagnostics
        )

        let footer =
            NSTextField(
                labelWithString:
                    "No virtual displays • No topology changes • Intel macOS Ventura 13+ • PanelGuard \(appVersion)"
            )

        footer.font =
            .systemFont(ofSize: 10.5)

        footer.textColor =
            .tertiaryLabelColor

        root.addArrangedSubview(
            footer
        )
    }

    private func makeCard()
        -> NSVisualEffectView {
        let card =
            NSVisualEffectView()

        card.material =
            .contentBackground

        card.blendingMode =
            .withinWindow

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
                equalTo:
                    container.leadingAnchor,
                constant: inset
            ),
            view.trailingAnchor.constraint(
                equalTo:
                    container.trailingAnchor,
                constant: -inset
            ),
            view.topAnchor.constraint(
                equalTo:
                    container.topAnchor,
                constant: inset
            ),
            view.bottomAnchor.constraint(
                equalTo:
                    container.bottomAnchor,
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

        let label =
            NSTextField(
                labelWithString: title
            )

        label.font =
            .systemFont(ofSize: 12.5)

        row.addArrangedSubview(label)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(control)

        row.widthAnchor
            .constraint(
                equalToConstant: 535
            )
            .isActive = true

        return row
    }

    private func buildStatusItem() {
        statusItem =
            NSStatusBar.system
            .statusItem(
                withLength:
                    NSStatusItem
                    .squareLength
            )

        statusItem.button?.image =
            NSImage(
                systemSymbolName:
                    "display",
                accessibilityDescription:
                    "PanelGuard"
            )

        let menu = NSMenu()

        let show =
            NSMenuItem(
                title:
                    "Show PanelGuard",
                action:
                    #selector(showWindow),
                keyEquivalent: ""
            )

        show.target = self
        menu.addItem(show)

        let toggle =
            NSMenuItem(
                title:
                    "Put Physical Display to Sleep",
                action:
                    #selector(primaryAction),
                keyEquivalent: ""
            )

        toggle.target = self
        toggle.tag = 1001
        menu.addItem(toggle)

        let test =
            NSMenuItem(
                title:
                    "Test for 10 Seconds",
                action:
                    #selector(testAction),
                keyEquivalent: ""
            )

        test.target = self
        test.tag = 1002
        menu.addItem(test)

        menu.addItem(.separator())

        let quit =
            NSMenuItem(
                title:
                    "Quit PanelGuard",
                action:
                    #selector(quitApp),
                keyEquivalent: "q"
            )

        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(
            ignoringOtherApps: true
        )
    }

    @objc private func quitApp() {
        if isGuarded {
            restoreDisplay(
                silent: false
            )

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
            activateGuard(
                autoRestoreAfter: 10
            )
        }
    }

    @objc private func settingsChanged() {
        let hold =
            holdSwitch.state == .on

        let restore =
            restoreSwitch.state == .on

        let keepAwake =
            awakeSwitch.state == .on

        UserDefaults.standard.set(
            hold,
            forKey: "holdAsleep"
        )

        UserDefaults.standard.set(
            restore,
            forKey: "restoreOnExit"
        )

        UserDefaults.standard.set(
            keepAwake,
            forKey: "keepMacAwake"
        )

        if var state = guardState,
           state.active {
            state.holdAsleep = hold
            state.restoreOnExit = restore
            guardState = state

            try? StateStore.save(
                state
            )

            if keepAwake {
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
            activateGuard(
                autoRestoreAfter: nil
            )
        }
    }

    private func activateGuard(
        autoRestoreAfter: TimeInterval?
    ) {
        let brightness =
            BrightnessController.shared

        guard DisplayPower.apiAvailable else {
            showError(
                "Display power control is unavailable",
                "PanelGuard could not access IODisplayWrangler on this Mac."
            )
            return
        }

        guard let display =
                brightness.builtInDisplay(),
              let currentBrightness =
                brightness.get(display) else {
            showError(
                "Built-in iMac display not found",
                "PanelGuard could not identify and read the built-in Apple display."
            )
            return
        }

        let stored =
            Float(
                UserDefaults.standard
                .double(
                    forKey:
                        "lastVisibleBrightness"
                )
            )

        let restoreBrightness =
            currentBrightness > 0.015
            ? currentBrightness
            : max(stored, 0.5)

        if currentBrightness > 0.015 {
            UserDefaults.standard.set(
                Double(
                    currentBrightness
                ),
                forKey:
                    "lastVisibleBrightness"
            )
        }

        primaryButton.isEnabled = false
        testButton.isEnabled = false

        statusTitle.stringValue =
            "Putting physical panel to sleep…"

        statusDetail.stringValue =
            "The existing display identity and desktop layout remain unchanged."

        guard brightness.set(
            0,
            display: display
        ) else {
            refreshCapability()

            showError(
                "Couldn’t prepare the panel",
                "PanelGuard could not lower the physical backlight before requesting display sleep."
            )
            return
        }

        let state = GuardState(
            active: true,
            displayID: display,
            restoreBrightness:
                restoreBrightness,
            holdAsleep:
                holdSwitch.state == .on,
            restoreOnExit:
                restoreSwitch.state == .on,
            autoRestoreAt:
                autoRestoreAfter.map {
                    Date()
                        .timeIntervalSince1970
                    + $0
                },
            parentPID: getpid()
        )

        do {
            try StateStore.save(state)
        } catch {
            _ = brightness.set(
                restoreBrightness,
                display: display
            )

            refreshCapability()

            showError(
                "Couldn’t arm crash recovery",
                "PanelGuard refused to continue because the safety state could not be saved."
            )
            return
        }

        guardState = state
        startWatchdog()

        if awakeSwitch.state == .on {
            startCaffeinate()
        }

        guard DisplayPower.requestSleep(),
              DisplayPower.waitForSleep(
                display,
                timeout: 2.5
              ) else {
            rollbackFailedSleep(
                state: state
            )
            return
        }

        updateUI()
    }

    private func rollbackFailedSleep(
        state: GuardState
    ) {
        var inactive = state
        inactive.active = false

        try? StateStore.save(
            inactive
        )

        guardState = inactive

        stopWatchdog()
        stopCaffeinate()

        _ = DisplayPower.requestWake()

        _ = BrightnessController.shared
            .set(
                state.restoreBrightness,
                display: state.displayID
            )

        updateUI()

        showError(
            "Display sleep did not hold",
            "PanelGuard restored normal operation. No displays were added or removed."
        )
    }

    private func restoreDisplay(
        silent: Bool = false
    ) {
        guard var state =
                guardState
                ?? StateStore.load(),
              state.active else {
            guardState = nil
            updateUI()
            return
        }

        state.active = false
        guardState = state

        try? StateStore.save(
            state
        )

        stopWatchdog()
        stopCaffeinate()

        let wakeRequested =
            DisplayPower.requestWake()

        let brightnessRestored =
            BrightnessController.shared
            .set(
                state.restoreBrightness,
                display: state.displayID
            )

        let awake =
            DisplayPower.waitForWake(
                state.displayID,
                timeout: 2.0
            )

        updateUI()

        if (!wakeRequested
            || !brightnessRestored
            || !awake)
            && !silent {
            showError(
                "The display needs a wake input",
                "PanelGuard released its sleep hold and restored brightness. Press any key or move the mouse once if macOS has not lit the display yet."
            )
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
                rollbackFailedSleep(
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

        // Keep the computer awake, but intentionally do NOT use -d,
        // because -d would fight PanelGuard's display-sleep request.
        process.arguments = [
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

        let display =
            brightness.builtInDisplay()

        if let display,
           let value =
            brightness.get(display),
           value > 0.015 {
            UserDefaults.standard.set(
                Double(value),
                forKey:
                    "lastVisibleBrightness"
            )
        }

        let oldPanelGuardDisplays =
            NSScreen.screens
            .filter {
                $0.localizedName
                    .hasPrefix(
                        "PanelGuard Remote Display"
                    )
            }
            .count

        diagnostics.stringValue =
            "IODisplayWrangler: \(DisplayPower.apiAvailable ? "ready" : "unavailable")   "
            + "Brightness: \(brightness.apiAvailable ? "ready" : "unavailable")\n"
            + "Built-in display: \(display.map { String(format: "0x%08X", $0) } ?? "not found")   "
            + "Old virtual PanelGuard displays: \(oldPanelGuardDisplays)\n"
            + "Topology changes in 1.3: NONE"

        primaryButton.isEnabled =
            DisplayPower.apiAvailable
            && brightness.apiAvailable
            && display != nil
            && oldPanelGuardDisplays == 0

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
                ? "Safe power-sleep test"
                : "Physical panel asleep"

            statusDetail.stringValue =
                testing
                ? "The original iMac display is asleep. It will restore automatically after 10 seconds."
                : "The same iMac display remains registered; PanelGuard is only holding its physical power state asleep."

            primaryButton.title =
                "Wake Physical Display"

            primaryButton.bezelColor =
                .systemGray

            primaryButton.isEnabled = true
            testButton.isEnabled = false

            statusItem.button?.image =
                NSImage(
                    systemSymbolName:
                        "display.trianglebadge.exclamationmark",
                    accessibilityDescription:
                        "PanelGuard active"
                )

            statusItem.menu?
                .item(withTag: 1001)?
                .title =
                "Wake Physical Display"

            statusItem.menu?
                .item(withTag: 1002)?
                .isEnabled = false

            if let state = guardState {
                diagnostics.stringValue =
                    "Display: \(String(format: "0x%08X", state.displayID))   "
                    + "asleep=\(CGDisplayIsAsleep(state.displayID) != 0 ? "YES" : "NO")\n"
                    + "Hold asleep: \(state.holdAsleep ? "ON" : "OFF")   "
                    + "Brightness rescue: F2 / Brightness Up\n"
                    + "Topology changes in 1.3: NONE"
            }
        } else {
            statusDot.textColor =
                .systemGreen

            statusTitle.stringValue =
                "Ready"

            statusDetail.stringValue =
                "The built-in display is unchanged. PanelGuard will use display power sleep only."

            primaryButton.title =
                "Put Physical Display to Sleep"

            primaryButton.bezelColor =
                .controlAccentColor

            statusItem.button?.image =
                NSImage(
                    systemSymbolName:
                        "display",
                    accessibilityDescription:
                        "PanelGuard"
                )

            statusItem.menu?
                .item(withTag: 1001)?
                .title =
                "Put Physical Display to Sleep"

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
        alert.beginSheetModal(
            for: window
        )
    }
}

private func restoreFromWatchdog(
    _ state: inout GuardState,
    url: URL
) -> Bool {
    state.active = false

    do {
        try StateStore.save(
            state,
            to: url
        )
    } catch {
        return false
    }

    let wake =
        DisplayPower.requestWake()

    let brightness =
        BrightnessController.shared
        .set(
            state.restoreBrightness,
            display: state.displayID
        )

    _ = DisplayPower.waitForWake(
        state.displayID,
        timeout: 1.5
    )

    return wake && brightness
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

    let url =
        URL(
            fileURLWithPath:
                arguments[3]
        )

    let brightness =
        BrightnessController.shared

    while true {
        guard var state =
                StateStore.load(from: url),
              state.active else {
            return 0
        }

        let now =
            Date().timeIntervalSince1970

        let timedOut =
            state.autoRestoreAt.map {
                now >= $0
            }
            ?? false

        errno = 0

        let parentGone =
            kill(parentPID, 0) != 0
            && errno == ESRCH

        if timedOut
            || (
                parentGone
                && state.restoreOnExit
            ) {
            _ = restoreFromWatchdog(
                &state,
                url: url
            )

            return 0
        }

        if parentGone
            && !state.restoreOnExit {
            return 0
        }

        // Hardware rescue: raising the built-in brightness means
        // "release PanelGuard". This does not depend on the app hotkey.
        if let current =
            brightness.get(
                state.displayID
            ),
           current > 0.035 {
            _ = restoreFromWatchdog(
                &state,
                url: url
            )

            return 0
        }

        if state.holdAsleep,
           CGDisplayIsAsleep(
                state.displayID
           ) == 0 {
            _ = brightness.set(
                0,
                display: state.displayID
            )

            _ = DisplayPower.requestSleep()
        }

        usleep(80_000)
    }
}

private func runSelfTest() -> Int32 {
    let brightness =
        BrightnessController.shared

    print(
        "PanelGuard \(appVersion)"
    )

    print(
        "IODisplayWrangler: "
        + (
            DisplayPower.apiAvailable
            ? "OK"
            : "FAIL"
        )
    )

    print(
        "DisplayServices brightness: "
        + (
            brightness.apiAvailable
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

        print(
            "Display asleep: "
            + (
                CGDisplayIsAsleep(
                    display
                ) != 0
                ? "YES"
                : "NO"
            )
        )

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
        print(
            "Built-in display: none"
        )
    }

    return DisplayPower.apiAvailable
        && brightness.apiAvailable
        ? 0
        : 2
}

let arguments =
    CommandLine.arguments

if arguments.contains(
    "--version"
) {
    print(appVersion)
    exit(0)
}

if arguments.contains(
    "--self-test"
) {
    exit(runSelfTest())
}

if arguments.count > 1,
   arguments[1] == "--watchdog" {
    exit(
        runWatchdog(arguments)
    )
}

let app =
    NSApplication.shared

private let delegate =
    AppDelegate()

app.delegate = delegate
app.run()
