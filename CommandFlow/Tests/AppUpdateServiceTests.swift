import Foundation
import XCTest
@testable import CommandFlow

@MainActor
final class AppUpdateServiceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!
    private var tempDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaultsSuiteName = "AppUpdateServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
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

    func testCheckForUpdatesMarksNewReleaseAsAvailable() async throws {
        let downloadedURL = try makeTempFile(named: "CommandFlow.dmg")
        let client = StubAppUpdateClient(
            latestRelease: makeRelease(tag: "v0.2.0"),
            downloadedFileURL: downloadedURL
        )
        let service = AppUpdateService(
            currentRelease: AppReleaseInfo(version: "0.1.0", build: "1", bundleIdentifier: "app.getcommandflow.commandflow"),
            defaults: defaults,
            client: client,
            automaticCheckInterval: 3600,
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        await service.checkForUpdates(source: .manual)

        XCTAssertEqual(service.availableRelease?.version, "0.2.0")
        XCTAssertNil(service.checkErrorMessage)
        XCTAssertEqual(client.fetchCount, 1)

        await service.downloadLatestRelease()

        XCTAssertEqual(service.downloadState, .downloaded(downloadedURL))
        XCTAssertEqual(client.downloadCount, 1)
    }

    func testCheckForUpdatesKeepsCurrentVersionUpToDate() async {
        let client = StubAppUpdateClient(
            latestRelease: makeRelease(tag: "0.1.0"),
            downloadedFileURL: tempDirectoryURL.appendingPathComponent("unused.dmg")
        )
        let service = AppUpdateService(
            currentRelease: AppReleaseInfo(version: "0.1.0", build: "1", bundleIdentifier: "app.getcommandflow.commandflow"),
            defaults: defaults,
            client: client,
            automaticCheckInterval: 3600,
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        await service.checkForUpdates(source: .manual)

        XCTAssertNil(service.availableRelease)
        XCTAssertEqual(service.latestRelease?.version, "0.1.0")
        XCTAssertNil(service.checkErrorMessage)
    }

    func testAutomaticChecksRespectThrottleWindow() async {
        let client = StubAppUpdateClient(
            latestRelease: makeRelease(tag: "0.3.0"),
            downloadedFileURL: tempDirectoryURL.appendingPathComponent("unused.dmg")
        )
        let currentDate = Date(timeIntervalSince1970: 1_700_000_000)

        let firstService = AppUpdateService(
            currentRelease: AppReleaseInfo(version: "0.1.0", build: "1", bundleIdentifier: "app.getcommandflow.commandflow"),
            defaults: defaults,
            client: client,
            automaticCheckInterval: 3600,
            now: { currentDate }
        )

        await firstService.checkForUpdates(source: .manual)
        XCTAssertEqual(client.fetchCount, 1)

        let throttledService = AppUpdateService(
            currentRelease: AppReleaseInfo(version: "0.1.0", build: "1", bundleIdentifier: "app.getcommandflow.commandflow"),
            defaults: defaults,
            client: client,
            automaticCheckInterval: 3600,
            now: { currentDate.addingTimeInterval(60) }
        )

        await throttledService.performAutomaticCheckIfNeeded()
        XCTAssertEqual(client.fetchCount, 1)

        let laterService = AppUpdateService(
            currentRelease: AppReleaseInfo(version: "0.1.0", build: "1", bundleIdentifier: "app.getcommandflow.commandflow"),
            defaults: defaults,
            client: client,
            automaticCheckInterval: 3600,
            now: { currentDate.addingTimeInterval(7200) }
        )

        await laterService.performAutomaticCheckIfNeeded()
        XCTAssertEqual(client.fetchCount, 2)
    }

    func testCheckForUpdatesExposesFailureReason() async {
        let client = StubAppUpdateClient(
            latestRelease: makeRelease(tag: "0.2.0"),
            downloadedFileURL: tempDirectoryURL.appendingPathComponent("unused.dmg")
        )
        client.fetchError = URLError(.notConnectedToInternet)

        let service = AppUpdateService(
            currentRelease: AppReleaseInfo(version: "0.1.0", build: "1", bundleIdentifier: "app.getcommandflow.commandflow"),
            defaults: defaults,
            client: client,
            automaticCheckInterval: 3600,
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        await service.checkForUpdates(source: .manual)

        XCTAssertNil(service.latestRelease)
        XCTAssertNotNil(service.checkErrorMessage)
    }

    private func makeRelease(tag: String) -> AppUpdateRelease {
        AppUpdateRelease(
            tagName: tag,
            title: "CommandFlow \(tag)",
            notes: "Release notes",
            releasePageURL: URL(string: "https://github.com/hugobnhl/CommandFlow/releases/tag/\(tag)")!,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            assets: [
                AppUpdateAsset(
                    name: "CommandFlow.dmg",
                    downloadURL: URL(string: "https://github.com/hugobnhl/CommandFlow/releases/download/\(tag)/CommandFlow.dmg")!,
                    downloadCount: 42
                ),
            ]
        )
    }

    private func makeTempFile(named name: String) throws -> URL {
        let fileURL = tempDirectoryURL.appendingPathComponent(name)
        try Data("test".utf8).write(to: fileURL)
        return fileURL
    }
}

private final class StubAppUpdateClient: AppUpdateClient {
    let latestRelease: AppUpdateRelease
    let downloadedFileURL: URL
    var fetchError: Error?
    private(set) var fetchCount = 0
    private(set) var downloadCount = 0

    init(latestRelease: AppUpdateRelease, downloadedFileURL: URL) {
        self.latestRelease = latestRelease
        self.downloadedFileURL = downloadedFileURL
    }

    func fetchLatestRelease() async throws -> AppUpdateRelease {
        fetchCount += 1

        if let fetchError {
            throw fetchError
        }

        return latestRelease
    }

    func downloadAsset(_ asset: AppUpdateAsset) async throws -> URL {
        downloadCount += 1
        return downloadedFileURL
    }
}
