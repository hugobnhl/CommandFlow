import Foundation

@MainActor
final class AppState: ObservableObject {
    let appName = "CommandFlow"
    let legacyBundleIdentifier = "com.commandflow.macos"
    let developmentBundleIdentifier = "com.hugobrun.commandflow.dev"

    @Published var statusMessage = "Fresh development environment ready."
    @Published var legacyReferenceAvailable: Bool

    init() {
        let referencePath = "/Users/hugobrun/Developer/CommandFlow/References/LegacyCommandFlowSnapshot"
        legacyReferenceAvailable = FileManager.default.fileExists(atPath: referencePath)
    }
}
