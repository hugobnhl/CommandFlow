import AppKit
import Foundation

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
