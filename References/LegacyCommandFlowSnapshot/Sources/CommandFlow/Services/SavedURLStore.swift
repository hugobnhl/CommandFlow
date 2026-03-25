import Foundation

@MainActor
final class SavedURLStore: ObservableObject {
    private enum DefaultsKey {
        static let items = "CommandFlow.savedURLItems"
        static let sortOrder = "CommandFlow.savedURLSortOrder"
    }

    @Published private(set) var items: [SavedURLItem]
    @Published var sortOrder: SavedURLSortOrder {
        didSet { defaults.set(sortOrder.rawValue, forKey: DefaultsKey.sortOrder) }
    }

    private let defaults = UserDefaults.standard
    private let router = ApplicationRouter()

    init() {
        items = Self.loadItems(from: defaults)
        sortOrder = SavedURLSortOrder(rawValue: defaults.string(forKey: DefaultsKey.sortOrder) ?? "") ?? .manual
    }

    var orderedItems: [SavedURLItem] {
        switch sortOrder {
        case .manual:
            return items
        case .recentlyAdded:
            return items.sorted { $0.createdAt > $1.createdAt }
        case .recentlyUsed:
            return items.sorted {
                let lhs = $0.lastUsedAt ?? .distantPast
                let rhs = $1.lastUsedAt ?? .distantPast
                if lhs == rhs {
                    return $0.createdAt > $1.createdAt
                }
                return lhs > rhs
            }
        case .alphabetical:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    func add(name: String, urlString: String) -> Bool {
        guard let normalized = normalize(urlString: urlString) else {
            return false
        }

        let resolvedName: String
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedName = URL(string: normalized)?.host ?? normalized
        } else {
            resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        items.insert(SavedURLItem(name: resolvedName, urlString: normalized), at: 0)
        persist()
        return true
    }

    func rename(_ item: SavedURLItem, to name: String) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        items[index].name = trimmed
        persist()
    }

    func delete(_ item: SavedURLItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func moveUp(_ item: SavedURLItem) {
        guard sortOrder == .manual,
              let index = items.firstIndex(where: { $0.id == item.id }),
              index > 0 else {
            return
        }

        items.swapAt(index, index - 1)
        persist()
    }

    func moveDown(_ item: SavedURLItem) {
        guard sortOrder == .manual,
              let index = items.firstIndex(where: { $0.id == item.id }),
              index < items.count - 1 else {
            return
        }

        items.swapAt(index, index + 1)
        persist()
    }

    func open(_ item: SavedURLItem, using preference: BrowserPreference) async throws {
        guard let url = URL(string: item.urlString) else {
            throw ActionExecutionError.invalidURL(item.urlString)
        }

        try await router.openURL(url, preference: preference)
        markUsed(item)
    }

    private func markUsed(_ item: SavedURLItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        items[index].lastUsedAt = .now
        items[index].usageCount += 1
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }
        defaults.set(data, forKey: DefaultsKey.items)
    }

    private func normalize(urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url.absoluteString
        }

        let prefixed = "https://\(trimmed)"
        guard let url = URL(string: prefixed) else {
            return nil
        }
        return url.absoluteString
    }

    private static func loadItems(from defaults: UserDefaults) -> [SavedURLItem] {
        guard let data = defaults.data(forKey: DefaultsKey.items),
              let items = try? JSONDecoder().decode([SavedURLItem].self, from: data) else {
            return []
        }
        return items
    }
}
