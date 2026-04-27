import Foundation
import XCTest
@testable import CommandFlow

@MainActor
final class DragDropStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!
    private var tempDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaultsSuiteName = "DragDropStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults = nil
        defaultsSuiteName = nil

        if let tempDirectoryURL {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }
        tempDirectoryURL = nil
        try super.tearDownWithError()
    }

    func testRegisterDroppedFileDeduplicatesPath() throws {
        let store = DragDropStore(defaults: defaults)
        let fileURL = try makeTempFile(named: "draft.txt")

        store.registerDroppedFile(fileURL)
        store.registerDroppedFile(fileURL)

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.latestDroppedFilePath, fileURL.path)
    }

    func testRegisterDroppedFileKeepsOnlyTenMostRecentItems() throws {
        let store = DragDropStore(defaults: defaults)

        for index in 0..<12 {
            let fileURL = try makeTempFile(named: "file-\(index).txt")
            store.registerDroppedFile(fileURL)
        }

        XCTAssertEqual(store.items.count, 10)
        XCTAssertEqual(store.items.first?.name, "file-2.txt")
        XCTAssertEqual(store.items.last?.name, "file-11.txt")
    }

    func testRemoveMultipleItemsUpdatesLatestPath() throws {
        let store = DragDropStore(defaults: defaults)
        let first = store.registerDroppedFile(try makeTempFile(named: "first.txt"))
        let second = store.registerDroppedFile(try makeTempFile(named: "second.txt"))
        let third = store.registerDroppedFile(try makeTempFile(named: "third.txt"))

        store.remove([second, third])

        XCTAssertEqual(store.items, [first])
        XCTAssertEqual(store.latestDroppedFilePath, first.path)
    }

    private func makeTempFile(named name: String) throws -> URL {
        let fileURL = tempDirectoryURL.appendingPathComponent(name)
        try Data("test".utf8).write(to: fileURL)
        return fileURL
    }
}
