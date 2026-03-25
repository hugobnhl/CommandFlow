import AppKit
import Foundation

@MainActor
final class DragDropStore: ObservableObject {
    private enum DefaultsKey {
        static let latestDroppedPath = "CommandFlow.latestDroppedPath"
    }

    @Published private(set) var latestDroppedFilePath: String?
    @Published private(set) var isInteractionActive = false

    private let defaults = UserDefaults.standard

    init() {
        latestDroppedFilePath = defaults.string(forKey: DefaultsKey.latestDroppedPath)
    }

    var latestDroppedFileURL: URL? {
        guard let latestDroppedFilePath else {
            return nil
        }
        return URL(fileURLWithPath: latestDroppedFilePath)
    }

    func setInteractionActive(_ active: Bool) {
        isInteractionActive = active
    }

    func registerDroppedFile(_ url: URL) {
        latestDroppedFilePath = url.path
        defaults.set(url.path, forKey: DefaultsKey.latestDroppedPath)
        isInteractionActive = false
    }

    @discardableResult
    func copyLatestFilePath() -> Bool {
        guard let latestDroppedFilePath else {
            return false
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(latestDroppedFilePath, forType: .string)
        return true
    }

    @discardableResult
    func revealLatestFile() -> Bool {
        guard let latestDroppedFileURL else {
            return false
        }

        NSWorkspace.shared.activateFileViewerSelecting([latestDroppedFileURL])
        return true
    }

    @discardableResult
    func openLatestFile() -> Bool {
        guard let latestDroppedFileURL else {
            return false
        }

        return NSWorkspace.shared.open(latestDroppedFileURL)
    }

    @discardableResult
    func previewLatestFile() -> Bool {
        guard let latestDroppedFileURL else {
            return false
        }

        if let previewURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([latestDroppedFileURL], withApplicationAt: previewURL, configuration: configuration, completionHandler: nil)
            return true
        }

        return NSWorkspace.shared.open(latestDroppedFileURL)
    }
}
