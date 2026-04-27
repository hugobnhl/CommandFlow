import XCTest
@testable import CommandFlow

@MainActor
final class QuickNoteStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "QuickNoteStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
    }

    override func tearDown() {
        if let defaults {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        defaults = nil
        defaultsSuiteName = nil
        super.tearDown()
    }

    func testAddTrimsAndPersistsNote() {
        let store = QuickNoteStore(defaults: defaults)

        store.add(text: "  ship this  ")

        XCTAssertEqual(store.notes.count, 1)
        XCTAssertEqual(store.notes[0].text, "ship this")

        let reloadedStore = QuickNoteStore(defaults: defaults)
        XCTAssertEqual(reloadedStore.notes.map(\.text), ["ship this"])
    }

    func testBlankUpdateKeepsExistingText() {
        let store = QuickNoteStore(defaults: defaults)
        store.add(text: "original")
        let note = store.notes[0]

        store.update(note, text: "   \n")

        XCTAssertEqual(store.notes[0].text, "original")
    }

    func testUpdateRewritesText() {
        let store = QuickNoteStore(defaults: defaults)
        store.add(text: "draft")
        let note = store.notes[0]

        store.update(note, text: "  final copy  ")

        XCTAssertEqual(store.notes[0].text, "final copy")
    }
}
