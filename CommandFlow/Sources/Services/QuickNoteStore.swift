import Foundation

@MainActor
final class QuickNoteStore: ObservableObject {
    private enum DefaultsKey {
        static let notes = "CommandFlow.quickNotes"
    }

    @Published private(set) var notes: [QuickNoteItem]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        notes = Self.loadNotes(from: defaults)
    }

    func add(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        notes.insert(QuickNoteItem(text: trimmed), at: 0)
        persist()
    }

    func update(_ note: QuickNoteItem, text: String) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else {
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        notes[index].text = trimmed
        notes[index].updatedAt = .now
        persist()
    }

    func delete(_ note: QuickNoteItem) {
        notes.removeAll { $0.id == note.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(notes) else {
            return
        }
        defaults.set(data, forKey: DefaultsKey.notes)
    }

    private static func loadNotes(from defaults: UserDefaults) -> [QuickNoteItem] {
        guard let data = defaults.data(forKey: DefaultsKey.notes),
              let notes = try? JSONDecoder().decode([QuickNoteItem].self, from: data) else {
            return []
        }
        return notes
    }
}
