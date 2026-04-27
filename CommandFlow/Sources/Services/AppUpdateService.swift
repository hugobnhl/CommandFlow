import AppKit
import Foundation

struct AppUpdateAsset: Decodable, Equatable, Identifiable {
    let name: String
    let downloadURL: URL
    let downloadCount: Int

    var id: String { name }

    var isDiskImage: Bool {
        name.lowercased().hasSuffix(".dmg")
    }

    var isZipArchive: Bool {
        name.lowercased().hasSuffix(".zip")
    }

    var kindLabel: String {
        if isDiskImage {
            return "DMG"
        }

        if isZipArchive {
            return "ZIP"
        }

        return "File"
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case downloadURL = "browser_download_url"
        case downloadCount = "download_count"
    }
}

struct AppUpdateRelease: Decodable, Equatable {
    let tagName: String
    let title: String
    let notes: String
    let releasePageURL: URL
    let publishedAt: Date?
    let assets: [AppUpdateAsset]

    var version: String {
        Self.normalizedVersion(from: tagName)
    }

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "CommandFlow \(version)" : trimmedTitle
    }

    var preferredAsset: AppUpdateAsset? {
        if let dmg = assets.first(where: \.isDiskImage) {
            return dmg
        }

        if let zip = assets.first(where: \.isZipArchive) {
            return zip
        }

        return assets.first
    }

    var preferredDownloadCount: Int? {
        preferredAsset?.downloadCount
    }

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case title = "name"
        case notes = "body"
        case releasePageURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }

    private static func normalizedVersion(from rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstDigitIndex = trimmed.firstIndex(where: \.isNumber) else {
            return trimmed
        }

        let suffix = trimmed[firstDigitIndex...]
        let components = suffix.split(separator: ".").map { component in
            component.prefix { $0.isNumber }
        }
        let versionComponents = components.compactMap { segment in
            segment.isEmpty ? nil : String(segment)
        }

        return versionComponents.isEmpty ? trimmed : versionComponents.joined(separator: ".")
    }
}

enum AppUpdateDownloadState: Equatable {
    case idle
    case downloading(String)
    case downloaded(URL)
    case failed(String)
}

protocol AppUpdateClient {
    func fetchLatestRelease() async throws -> AppUpdateRelease
    func downloadAsset(_ asset: AppUpdateAsset) async throws -> URL
}

enum AppUpdateClientError: LocalizedError {
    case invalidResponse
    case missingAsset

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The update server returned an invalid response."
        case .missingAsset:
            return "The latest release does not include a DMG or ZIP download yet."
        }
    }
}

struct GitHubAppUpdateClient: AppUpdateClient {
    let owner: String
    let repository: String
    let session: URLSession
    let fileManager: FileManager

    init(
        owner: String = "hugobnhl",
        repository: String = "CommandFlow",
        session: URLSession = .shared,
        fileManager: FileManager = .default
    ) {
        self.owner = owner
        self.repository = repository
        self.session = session
        self.fileManager = fileManager
    }

    func fetchLatestRelease() async throws -> AppUpdateRelease {
        let endpoint = URL(string: "https://api.github.com/repos/\(owner)/\(repository)/releases/latest")!
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CommandFlow-Updater", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        try validate(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppUpdateRelease.self, from: data)
    }

    func downloadAsset(_ asset: AppUpdateAsset) async throws -> URL {
        var request = URLRequest(url: asset.downloadURL)
        request.setValue("CommandFlow-Updater", forHTTPHeaderField: "User-Agent")

        let (temporaryURL, response) = try await session.download(for: request)
        try validate(response)

        let downloadsDirectoryURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        try fileManager.createDirectory(at: downloadsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let destinationURL = uniqueDestinationURL(
            in: downloadsDirectoryURL,
            preferredFilename: asset.name
        )

        try? fileManager.removeItem(at: destinationURL)
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw AppUpdateClientError.invalidResponse
        }
    }

    private func uniqueDestinationURL(in directoryURL: URL, preferredFilename: String) -> URL {
        let preferredURL = directoryURL.appendingPathComponent(preferredFilename)
        guard !fileManager.fileExists(atPath: preferredURL.path) else {
            let baseName = preferredURL.deletingPathExtension().lastPathComponent
            let fileExtension = preferredURL.pathExtension

            for index in 2...100 {
                let candidateName = fileExtension.isEmpty
                    ? "\(baseName)-\(index)"
                    : "\(baseName)-\(index).\(fileExtension)"
                let candidateURL = directoryURL.appendingPathComponent(candidateName)
                if !fileManager.fileExists(atPath: candidateURL.path) {
                    return candidateURL
                }
            }

            return directoryURL.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
        }

        return preferredURL
    }
}

@MainActor
final class AppUpdateService: ObservableObject {
    private enum DefaultsKey {
        static let lastCheckDate = "CommandFlow.updates.lastCheckDate"
    }

    enum CheckSource {
        case automatic
        case manual
    }

    @Published private(set) var latestRelease: AppUpdateRelease?
    @Published private(set) var lastCheckDate: Date?
    @Published private(set) var isChecking = false
    @Published private(set) var checkErrorMessage: String?
    @Published private(set) var downloadState: AppUpdateDownloadState = .idle

    let currentRelease: AppReleaseInfo

    private let defaults: UserDefaults
    private let client: AppUpdateClient
    private let now: () -> Date
    private let automaticCheckInterval: TimeInterval

    init(
        currentRelease: AppReleaseInfo = .current,
        defaults: UserDefaults = .standard,
        client: AppUpdateClient = GitHubAppUpdateClient(),
        automaticCheckInterval: TimeInterval = 60 * 60 * 24,
        now: @escaping () -> Date = Date.init
    ) {
        self.currentRelease = currentRelease
        self.defaults = defaults
        self.client = client
        self.automaticCheckInterval = automaticCheckInterval
        self.now = now
        lastCheckDate = defaults.object(forKey: DefaultsKey.lastCheckDate) as? Date
    }

    var availableRelease: AppUpdateRelease? {
        guard let latestRelease else {
            return nil
        }

        guard Self.isVersion(latestRelease.version, newerThan: currentRelease.version) else {
            return nil
        }

        return latestRelease
    }

    var primaryAsset: AppUpdateAsset? {
        availableRelease?.preferredAsset
    }

    var latestVersionLabel: String {
        availableRelease?.version ?? latestRelease?.version ?? currentRelease.version
    }

    func performAutomaticCheckIfNeeded() async {
        if let lastCheckDate, now().timeIntervalSince(lastCheckDate) < automaticCheckInterval {
            return
        }

        await checkForUpdates(source: .automatic)
    }

    func checkForUpdates(source: CheckSource) async {
        guard !isChecking else {
            return
        }

        isChecking = true
        checkErrorMessage = nil

        let attemptedAt = now()
        lastCheckDate = attemptedAt
        defaults.set(attemptedAt, forKey: DefaultsKey.lastCheckDate)

        defer {
            isChecking = false
        }

        do {
            let release = try await client.fetchLatestRelease()
            let previousVersion = latestRelease?.version
            latestRelease = release

            if previousVersion != release.version {
                downloadState = .idle
            }
        } catch {
            let description = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            checkErrorMessage = description

            if source == .manual {
                downloadState = .idle
            }
        }
    }

    func downloadLatestRelease() async {
        guard let asset = primaryAsset else {
            downloadState = .failed(AppUpdateClientError.missingAsset.localizedDescription)
            return
        }

        downloadState = .downloading(asset.name)

        do {
            let downloadedURL = try await client.downloadAsset(asset)
            downloadState = .downloaded(downloadedURL)
        } catch {
            let description = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            downloadState = .failed(description)
        }
    }

    func revealDownloadedFile() {
        guard case let .downloaded(fileURL) = downloadState else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        compareVersion(lhs, rhs) == .orderedDescending
    }

    private static func compareVersion(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsComponents = normalizedComponents(from: lhs)
        let rhsComponents = normalizedComponents(from: rhs)
        let maxCount = max(lhsComponents.count, rhsComponents.count)

        for index in 0..<maxCount {
            let lhsValue = index < lhsComponents.count ? lhsComponents[index] : 0
            let rhsValue = index < rhsComponents.count ? rhsComponents[index] : 0

            if lhsValue > rhsValue {
                return .orderedDescending
            }

            if lhsValue < rhsValue {
                return .orderedAscending
            }
        }

        return .orderedSame
    }

    private static func normalizedComponents(from rawValue: String) -> [Int] {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstDigitIndex = trimmed.firstIndex(where: \.isNumber) else {
            return []
        }

        let suffix = trimmed[firstDigitIndex...]
        return suffix.split(separator: ".").compactMap { segment in
            let digits = segment.prefix { $0.isNumber }
            guard !digits.isEmpty else {
                return nil
            }
            return Int(digits)
        }
    }
}
