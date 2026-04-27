import AppKit
import Foundation

struct FrontmostApplicationContext: Equatable, Sendable {
    let name: String
    let bundleIdentifier: String

    var isBrowserLike: Bool {
        let browserBundleIDs: Set<String> = [
            "com.apple.Safari",
            "com.apple.SafariTechnologyPreview",
            "com.google.Chrome",
            "com.brave.Browser",
            "com.microsoft.edgemac",
            "com.operasoftware.Opera",
            "org.mozilla.firefox",
            "company.thebrowser.Browser",
            "com.vivaldi.Vivaldi",
            "com.kagi.kagimacOS",
        ]
        return browserBundleIDs.contains(bundleIdentifier)
    }
}

struct ApplicationRouter: Sendable {

    func isInstalled(bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    func availableBrowserPreferences() -> [BrowserPreference] {
        BrowserPreference.allCases.filter { preference in
            guard let bundleID = preference.bundleID else {
                return true
            }
            return isInstalled(bundleID: bundleID)
        }
    }

    func availableMailPreferences() -> [MailPreference] {
        MailPreference.allCases.filter { preference in
            guard let bundleID = preference.bundleID else {
                return true
            }
            return isInstalled(bundleID: bundleID)
        }
    }

    @MainActor
    func frontmostApplicationContext(excluding excludedBundleIdentifiers: Set<String>) -> FrontmostApplicationContext? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = application.bundleIdentifier,
              !excludedBundleIdentifiers.contains(bundleIdentifier)
        else {
            return nil
        }

        let name = application.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = (name?.isEmpty == false ? name : nil) ?? bundleIdentifier
        return FrontmostApplicationContext(name: displayName, bundleIdentifier: bundleIdentifier)
    }

    @MainActor
    func activateRunningApplication(bundleID: String) async throws {
        guard let application = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            throw ActionExecutionError.applicationNotFound(bundleID)
        }

        guard application.activate() else {
            throw ActionExecutionError.commandFailed("macOS could not activate \(application.localizedName ?? bundleID).")
        }
    }

    @MainActor
    func openURL(_ url: URL, preference: BrowserPreference) async throws {
        if let bundleID = preference.bundleID {
            try await open(urls: [url], bundleID: bundleID)
            return
        }

        guard NSWorkspace.shared.open(url) else {
            throw ActionExecutionError.commandFailed("macOS could not open that URL.")
        }
    }

    @MainActor
    func openMail(preference: MailPreference) async throws {
        if let bundleID = preference.bundleID {
            try await openApplication(bundleID: bundleID)
            return
        }

        if let mailURL = URL(string: "mailto:hello@commandflow.app"),
           let applicationURL = NSWorkspace.shared.urlForApplication(toOpen: mailURL) {
            let configuration = NSWorkspace.OpenConfiguration()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { _, error in
                    if let error {
                        continuation.resume(throwing: ActionExecutionError.commandFailed(error.localizedDescription))
                    } else {
                        continuation.resume()
                    }
                }
            }
            return
        }

        if let mailURL = URL(string: "mailto:") {
            guard NSWorkspace.shared.open(mailURL) else {
                throw ActionExecutionError.commandFailed("macOS could not open the default mail app.")
            }
        }
    }

    @MainActor
    func openApplication(bundleID: String) async throws {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw ActionExecutionError.applicationNotFound(bundleID)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                if let error {
                    continuation.resume(throwing: ActionExecutionError.commandFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    @MainActor
    private func open(urls: [URL], bundleID: String) async throws {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw ActionExecutionError.applicationNotFound(bundleID)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.open(urls, withApplicationAt: applicationURL, configuration: configuration) { _, error in
                if let error {
                    continuation.resume(throwing: ActionExecutionError.commandFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
