import SwiftUI

@main
struct CommandFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                store: appDelegate.appModel.store,
                clipboardStore: appDelegate.appModel.clipboardHistoryStore,
                savedURLStore: appDelegate.appModel.savedURLStore,
                quickNoteStore: appDelegate.appModel.quickNoteStore,
                showOnboarding: {
                    appDelegate.appModel.presentOnboarding()
                }
            )
        }
    }
}
