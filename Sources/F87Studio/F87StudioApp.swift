import AppKit
import SwiftUI

@main
struct F87StudioApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(model.profileStore)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1240, height: 800)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo Per-key Edit") { model.undoPerKey() }
                    .keyboardShortcut("z", modifiers: [.command])
                    .disabled(!model.canUndo)
                Button("Redo Per-key Edit") { model.redoPerKey() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!model.canRedo)
            }
            CommandMenu("Keyboard") {
                Button("Scan for F87") { model.scan() }.keyboardShortcut("r", modifiers: [.command])
                Divider()
                Button("Apply Lighting") { model.applyEffect() }.keyboardShortcut(.return, modifiers: [.command])
                    .disabled(!model.connectionState.isConnected)
                Button("Apply Per-key Colors") { model.applyPerKey() }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                    .disabled(!model.connectionState.isConnected)
                Divider()
                Button(model.isMusicReactive ? "Stop Music Mode" : "Start Music Mode") {
                    if model.isMusicReactive { model.stopMusicMode() } else { model.startMusicMode() }
                }
            }
        }
        MenuBarExtra("F87 Studio", systemImage: "keyboard") {
            MenuBarProfileView()
                .environmentObject(model)
                .environmentObject(model.profileStore)
        }
    }

}

struct MenuBarProfileView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: ProfileStore

    var body: some View {
        Button("Show F87 Studio") {
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
        }
        Text(model.connectionState.title)
        Divider()
        if store.profiles.isEmpty {
            Text("No saved profiles")
        } else {
            ForEach(store.profiles) { profile in
                Button(profile.name) { model.applyLibraryProfile(profile.id) }
            }
        }
        Divider()
        Toggle("Mac function row", isOn: Binding(
            get: { model.functionRowController.isEnabled },
            set: { model.functionRowController.isEnabled = $0 }
        ))
        Divider()
        Button("Scan for keyboard") { model.scan() }
        Button("Quit F87 Studio") { NSApplication.shared.terminate(nil) }
    }
}
