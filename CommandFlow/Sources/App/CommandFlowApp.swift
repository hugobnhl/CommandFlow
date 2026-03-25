import AppKit
import SwiftUI

@main
struct CommandFlowApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("CommandFlow", systemImage: "command") {
            MenuBarHomeView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

