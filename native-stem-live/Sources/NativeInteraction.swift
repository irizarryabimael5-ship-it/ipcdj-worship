import SwiftUI
import AppKit

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.isMovableByWindowBackground = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.tabbingMode = .disallowed
        window.collectionBehavior.insert(.fullScreenPrimary)
    }
}

final class ImmediateNSButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { false }
}

struct ImmediateTabButton: NSViewRepresentable {
    let title: String
    let active: Bool
    let action: () -> Void

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func fire() { action() }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> ImmediateNSButton {
        let button = ImmediateNSButton(title: title, target: context.coordinator, action: #selector(Coordinator.fire))
        button.isBordered = false
        button.focusRingType = .none
        button.wantsLayer = true
        button.font = NSFont.systemFont(ofSize: 10.5, weight: .heavy)
        button.alignment = .center
        button.setButtonType(.momentaryPushIn)
        button.toolTip = title
        update(button, coordinator: context.coordinator)
        return button
    }

    func updateNSView(_ nsView: ImmediateNSButton, context: Context) {
        context.coordinator.action = action
        update(nsView, coordinator: context.coordinator)
    }

    private func update(_ button: ImmediateNSButton, coordinator: Coordinator) {
        button.title = title
        button.contentTintColor = active ? .black : NSColor.secondaryLabelColor
        button.layer?.cornerRadius = 11
        button.layer?.backgroundColor = active
            ? NSColor.white.cgColor
            : NSColor.clear.cgColor
        button.layer?.borderWidth = active ? 0 : 0
        button.layer?.masksToBounds = true
    }
}

struct InstallLocationGate: View {
    var isRunningFromDiskImage: Bool {
        Bundle.main.bundleURL.path.hasPrefix("/Volumes/")
    }

    var body: some View {
        if isRunningFromDiskImage {
            ZStack {
                Color.black.opacity(0.82).ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 68, height: 68)
                    Text("Install STEM Live Native")
                        .font(.system(size: 26, weight: .bold))
                    Text("You're running the app directly from the disk image. For a stable live-performance installation, drag STEM Live Native into Applications and replace the existing copy, then eject the disk image and open the app from Applications.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: 520)
                        .lineSpacing(4)
                    HStack(spacing: 10) {
                        Button("OPEN APPLICATIONS") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
                        }
                        .buttonStyle(SmallButton(primary: true))
                        Button("QUIT") {
                            NSApp.terminate(nil)
                        }
                        .buttonStyle(SmallButton(primary: false))
                    }
                }
                .padding(34)
                .background(RoundedRectangle(cornerRadius: 28).fill(.regularMaterial))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.12)))
                .padding(40)
            }
            .zIndex(500)
        }
    }
}
