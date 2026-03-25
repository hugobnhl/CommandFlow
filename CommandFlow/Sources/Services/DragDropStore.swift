import AppKit
import Foundation

struct DroppedFileItem: Codable, Identifiable, Equatable {
    let id: UUID
    let path: String

    init(id: UUID = UUID(), path: String) {
        self.id = id
        self.path = path
    }

    var url: URL {
        URL(fileURLWithPath: path)
    }

    var name: String {
        url.lastPathComponent
    }
}

@MainActor
final class DragDropStore: ObservableObject {
    private enum DefaultsKey {
        static let latestDroppedPath = "CommandFlow.latestDroppedPath"
        static let droppedItems = "CommandFlow.droppedItems"
    }

    @Published private(set) var latestDroppedFilePath: String?
    @Published private(set) var items: [DroppedFileItem]
    @Published private(set) var isInteractionActive = false

    private let defaults = UserDefaults.standard
    private let maximumItems = 10

    init() {
        if let storedData = defaults.data(forKey: DefaultsKey.droppedItems),
           let decodedItems = try? JSONDecoder().decode([DroppedFileItem].self, from: storedData) {
            items = decodedItems.filter { FileManager.default.fileExists(atPath: $0.path) }
        } else if let latestDroppedFilePath = defaults.string(forKey: DefaultsKey.latestDroppedPath),
                  FileManager.default.fileExists(atPath: latestDroppedFilePath) {
            items = [DroppedFileItem(path: latestDroppedFilePath)]
        } else {
            items = []
        }

        latestDroppedFilePath = items.last?.path
        persistItems()
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

    @discardableResult
    func registerDroppedFile(_ url: URL) -> DroppedFileItem {
        let normalizedPath = url.path
        items.removeAll { $0.path == normalizedPath }

        let item = DroppedFileItem(path: normalizedPath)
        items.append(item)

        if items.count > maximumItems {
            items = Array(items.suffix(maximumItems))
        }

        latestDroppedFilePath = item.path
        persistItems()
        isInteractionActive = false
        return item
    }

    func remove(_ item: DroppedFileItem) {
        items.removeAll { $0.id == item.id }
        latestDroppedFilePath = items.last?.path
        persistItems()
    }

    @discardableResult
    func copyFilePath(for item: DroppedFileItem?) -> Bool {
        guard let path = resolvedItem(item)?.path else {
            return false
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        return true
    }

    @discardableResult
    func revealFile(_ item: DroppedFileItem?) -> Bool {
        guard let latestDroppedFileURL = resolvedItem(item)?.url else {
            return false
        }

        NSWorkspace.shared.activateFileViewerSelecting([latestDroppedFileURL])
        return true
    }

    @discardableResult
    func openFile(_ item: DroppedFileItem?) -> Bool {
        guard let latestDroppedFileURL = resolvedItem(item)?.url else {
            return false
        }

        return NSWorkspace.shared.open(latestDroppedFileURL)
    }

    @discardableResult
    func previewFile(_ item: DroppedFileItem?) -> Bool {
        guard let latestDroppedFileURL = resolvedItem(item)?.url else {
            return false
        }

        if let previewURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([latestDroppedFileURL], withApplicationAt: previewURL, configuration: configuration, completionHandler: nil)
            return true
        }

        return NSWorkspace.shared.open(latestDroppedFileURL)
    }

    @discardableResult
    func copyLatestFilePath() -> Bool {
        copyFilePath(for: nil)
    }

    @discardableResult
    func revealLatestFile() -> Bool {
        revealFile(nil)
    }

    @discardableResult
    func openLatestFile() -> Bool {
        openFile(nil)
    }

    @discardableResult
    func previewLatestFile() -> Bool {
        previewFile(nil)
    }

    private func resolvedItem(_ item: DroppedFileItem?) -> DroppedFileItem? {
        if let item {
            return items.first(where: { $0.id == item.id })
        }

        guard let latestDroppedFilePath else {
            return nil
        }
        return items.last(where: { $0.path == latestDroppedFilePath }) ?? items.last
    }

    private func persistItems() {
        if let latestPath = items.last?.path {
            defaults.set(latestPath, forKey: DefaultsKey.latestDroppedPath)
        } else {
            defaults.removeObject(forKey: DefaultsKey.latestDroppedPath)
        }

        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: DefaultsKey.droppedItems)
        } else {
            defaults.removeObject(forKey: DefaultsKey.droppedItems)
        }
    }
}
