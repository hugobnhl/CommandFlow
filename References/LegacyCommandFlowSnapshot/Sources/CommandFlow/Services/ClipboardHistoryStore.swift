import AppKit
import Combine
import Foundation

struct ClipboardHistoryItem: Identifiable, Codable, Hashable {
    let id: UUID
    let value: String
    let createdAt: Date

    init(id: UUID = UUID(), value: String, createdAt: Date = .now) {
        self.id = id
        self.value = value
        self.createdAt = createdAt
    }
}

@MainActor
final class ClipboardHistoryStore: ObservableObject {
    private enum DefaultsKey {
        static let history = "CommandFlow.clipboardHistory"
    }

    @Published private(set) var items: [ClipboardHistoryItem] = []
    @Published private(set) var lastCopiedItemID: ClipboardHistoryItem.ID?

    let limit: Int

    private let pasteboard = NSPasteboard.general
    private let permissionCenter = PermissionCenter()
    private let defaults = UserDefaults.standard
    private var lastChangeCount: Int
    private var monitor: AnyCancellable?

    init(limit: Int = 20) {
        self.limit = limit
        self.lastChangeCount = pasteboard.changeCount
        self.items = loadPersistedItems()
        seedFromCurrentClipboard()
        startMonitoring()
    }

    func copy(_ item: ClipboardHistoryItem) {
        writeToPasteboard(item.value)
        lastCopiedItemID = item.id
    }

    func paste(_ item: ClipboardHistoryItem) {
        copy(item)

        guard permissionCenter.accessibilityGranted() else {
            return
        }

        let script = NSAppleScript(source: """
        tell application "System Events"
            keystroke "v" using {command down}
        end tell
        """)

        var errorInfo: NSDictionary?
        script?.executeAndReturnError(&errorInfo)
    }

    func clear() {
        items.removeAll()
        persistItems()
    }

    private func startMonitoring() {
        monitor = Timer.publish(every: 0.75, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.captureClipboardIfNeeded()
            }
    }

    private func captureClipboardIfNeeded() {
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }

        lastChangeCount = pasteboard.changeCount

        guard let string = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !string.isEmpty else {
            return
        }

        insert(string)
    }

    private func seedFromCurrentClipboard() {
        guard let current = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !current.isEmpty else {
            return
        }

        if items.first?.value != current {
            insert(current)
        }
    }

    private func insert(_ value: String) {
        items.removeAll { $0.value == value }
        items.insert(ClipboardHistoryItem(value: value), at: 0)
        items = Array(items.prefix(limit))
        persistItems()
    }

    private func writeToPasteboard(_ value: String) {
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    private func persistItems() {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }
        defaults.set(data, forKey: DefaultsKey.history)
    }

    private func loadPersistedItems() -> [ClipboardHistoryItem] {
        guard let data = defaults.data(forKey: DefaultsKey.history),
              let items = try? JSONDecoder().decode([ClipboardHistoryItem].self, from: data) else {
            return []
        }
        return Array(items.prefix(limit))
    }
}
