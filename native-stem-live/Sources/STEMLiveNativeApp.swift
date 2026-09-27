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
                .frame(minWidth: 1180, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
