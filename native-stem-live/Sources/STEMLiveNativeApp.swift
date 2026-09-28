import SwiftUI
import AppKit

@main
struct STEMLiveNativeApp: App {
    @StateObject private var store = ProjectStore()
    @StateObject private var audio = AudioEngineController()

    init() {
        RuntimeDiagnostics.install()
    }

    var body: some Scene {
        WindowGroup("STEM Live Native") {
            ContentView()
                .environmentObject(store)
                .environmentObject(audio)
                .environmentObject(audio.performance)
                .frame(minWidth: 1280, minHeight: 780)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Song") {
                    store.addSong()
                    store.page = .set
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Import Stems…") {
                    store.page = .arrange
                }
                .keyboardShortcut("i", modifiers: [.command])
            }

            CommandMenu("Transport") {
                Button(audio.isPlaying ? "Pause" : "Play") {
                    if let song = store.currentSong {
                        audio.togglePlay(song: song)
                    }
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Stop") {
                    audio.stop(immediate: true)
                }
                .keyboardShortcut(".", modifiers: [.command])

                Divider()

                Button(audio.loopEnabled ? "Disable Loop" : "Enable Loop") {
                    audio.setLoopEnabled(!audio.loopEnabled)
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Button("Previous Section") {
                    jumpSection(delta: -1)
                }
                .keyboardShortcut("[", modifiers: [.command])

                Button("Next Section") {
                    jumpSection(delta: 1)
                }
                .keyboardShortcut("]", modifiers: [.command])

                Divider()

                Button("Fade Out") {
                    audio.fadeOut(seconds: 6.5)
                }
                .keyboardShortcut("f", modifiers: [.option])
                .disabled(!audio.isPlaying)
            }

            CommandMenu("Workspace") {
                ForEach(Array(WorkspacePage.allCases.enumerated()), id: \.element.id) { index, page in
                    Button(page.rawValue.capitalized) {
                        store.page = page
                        if page != .live && store.focusMode {
                            store.setFocusMode(false)
                        }
                    }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.command])
                }
            }

            CommandGroup(after: .sidebar) {
                Toggle(
                    "Show Setlist Sidebar",
                    isOn: Binding(
                        get: { store.sidebarVisible },
                        set: { store.setSidebarVisible($0) }
                    )
                )
                .keyboardShortcut("s", modifiers: [.command, .option])

                Toggle(
                    "Focused Live Mode",
                    isOn: Binding(
                        get: { store.focusMode },
                        set: { store.setFocusMode($0) }
                    )
                )
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Toggle(
                    "Living Color",
                    isOn: Binding(
                        get: { store.livingColorEnabled },
                        set: { store.livingColorEnabled = $0; store.save() }
                    )
                )

                Button("Reset STEM Live View") {
                    store.resetViewPreferences()
                }
            }

            CommandGroup(after: .help) {
                Button("Reveal Runtime Audio Log") {
                    NSWorkspace.shared.activateFileViewerSelecting([RuntimeDiagnostics.fileURL])
                }

                Button("Open System / Audio Preflight") {
                    store.setFocusMode(false)
                    store.page = .system
                }
            }
        }
    }

    private func jumpSection(delta: Int) {
        guard let song = store.currentSong, !song.sections.isEmpty else { return }
        let now = audio.currentTime
        let current = song.sections.lastIndex(where: { $0.start <= now }) ?? 0
        let target = min(max(0, current + delta), song.sections.count - 1)
        let section = song.sections[target]
        store.selectedSectionID = section.id
        audio.jumpToSection(section, song: song)
    }
}
