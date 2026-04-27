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

    private let defaults: UserDefaults
    private let maximumItems = 10
    private let quickLookPreviewManager = QuickLookPreviewManager.shared

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
        remove([item])
    }

    func remove(_ itemsToRemove: [DroppedFileItem]) {
        let removalIDs = Set(itemsToRemove.map(\.id))
        guard !removalIDs.isEmpty else {
            return
        }

        items.removeAll { removalIDs.contains($0.id) }
        latestDroppedFilePath = items.last?.path
        persistItems()
    }

    @discardableResult
    func copyFilePath(for item: DroppedFileItem?) -> Bool {
        copyFilePaths(for: item.map { [$0] } ?? [])
    }

    @discardableResult
    func copyFilePaths(for itemsToCopy: [DroppedFileItem]) -> Bool {
        let resolved = resolvedItems(itemsToCopy)
        guard !resolved.isEmpty else {
            return false
        }

        let value = resolved.map(\.path).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        return true
    }

    @discardableResult
    func revealFile(_ item: DroppedFileItem?) -> Bool {
        revealFiles(item.map { [$0] } ?? [])
    }

    @discardableResult
    func revealFiles(_ itemsToReveal: [DroppedFileItem]) -> Bool {
        let urls = resolvedItems(itemsToReveal).map(\.url)
        guard !urls.isEmpty else {
            return false
        }

        NSWorkspace.shared.activateFileViewerSelecting(urls)
        return true
    }

    @discardableResult
    func openFile(_ item: DroppedFileItem?) -> Bool {
        openFiles(item.map { [$0] } ?? [])
    }

    @discardableResult
    func openFiles(_ itemsToOpen: [DroppedFileItem]) -> Bool {
        let urls = resolvedItems(itemsToOpen).map(\.url)
        guard !urls.isEmpty else {
            return false
        }

        return urls.reduce(into: true) { result, url in
            result = NSWorkspace.shared.open(url) && result
        }
    }

    @discardableResult
    func previewFile(_ item: DroppedFileItem?) -> Bool {
        previewFiles(item.map { [$0] } ?? [])
    }

    @discardableResult
    func previewFiles(_ itemsToPreview: [DroppedFileItem]) -> Bool {
        let urls = resolvedItems(itemsToPreview).map(\.url)
        guard !urls.isEmpty else {
            return false
        }

        quickLookPreviewManager.present(items: urls)
        return true
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

    private func resolvedItems(_ itemsToResolve: [DroppedFileItem]) -> [DroppedFileItem] {
        if !itemsToResolve.isEmpty {
            let ids = Set(itemsToResolve.map(\.id))
            return items.filter { ids.contains($0.id) }
        }

        guard let latest = resolvedItem(nil) else {
            return []
        }

        return [latest]
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
