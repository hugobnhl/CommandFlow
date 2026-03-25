import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appModel = CommandFlowAppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        appModel.start()
    }
}
