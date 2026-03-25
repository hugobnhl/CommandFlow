import SwiftUI

@main
struct CommandFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            appDelegate.appModel.makeSettingsView()
        }
    }
}
