import SwiftUI
import AppKit

@main
struct STEMLiveNativeApp: App {
    @StateObject private var store = ProjectStore()
    @StateObject private var audio = AudioEngineController()

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup("STEM Live Native") {
            ContentView()
                .environmentObject(store)
                .environmentObject(audio)
                .frame(minWidth: 1280, minHeight: 780)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) { }

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
            }

            CommandMenu("Workspace") {
                Button("Live") { store.page = .live }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("Arrange") { store.page = .arrange }
                    .keyboardShortcut("3", modifiers: [.command])
                Button("Mix") { store.page = .mix }
                    .keyboardShortcut("4", modifiers: [.command])
            }
        }
    }
}
