import Foundation

struct AppReleaseInfo: Equatable {
    let name: String
    let version: String
    let build: String
    let bundleIdentifier: String

    static let current = AppReleaseInfo(bundle: .main)

    init(bundle: Bundle) {
        name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "CommandFlow"
        version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        bundleIdentifier = bundle.bundleIdentifier ?? "unknown.bundle"
    }

    init(name: String = "CommandFlow", version: String, build: String, bundleIdentifier: String) {
        self.name = name
        self.version = version
        self.build = build
        self.bundleIdentifier = bundleIdentifier
    }
}
