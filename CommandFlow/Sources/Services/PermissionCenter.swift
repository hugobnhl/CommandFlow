import AppKit
import ApplicationServices
import Foundation
import OSLog

struct PermissionCenter: Sendable {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.hugobrun.commandflow.dev",
        category: "permissions"
    )

    func accessibilityGranted() -> Bool {
        AXIsProcessTrustedWithOptions(accessibilityOptions(prompt: false))
    }

    @MainActor
    func requestAccessibilityPrompt() {
        logger.info("Requesting accessibility permission prompt")
        _ = AXIsProcessTrustedWithOptions(accessibilityOptions(prompt: true))
    }

    @MainActor
    func openAccessibilitySettings() {
        _ = openSettingsURLs([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
        ])
    }

    @MainActor
    func openAutomationSettings() {
        _ = openSettingsURLs([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
            "x-apple.systempreferences:com.apple.preference.security?Privacy",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
        ])
    }

    @MainActor
    func requestAutomationPrompt() {
        logger.info("Requesting automation permission prompt through Finder")

        guard let script = NSAppleScript(source: """
        tell application "Finder"
            get name of startup disk
        end tell
        """) else {
            logger.error("Failed to create automation prompt AppleScript")
            return
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            logger.warning("Automation prompt script returned: \(message, privacy: .public)")
        } else {
            logger.info("Automation prompt script executed successfully")
        }
    }

    @MainActor
    private func openSettingsURLs(_ candidates: [String]) -> Bool {
        for candidate in candidates {
            if openSettingsURL(candidate) {
                logger.info("Opened System Settings using candidate: \(candidate, privacy: .public)")
                return true
            }
        }

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") {
            let opened = NSWorkspace.shared.open(appURL)
            if opened {
                logger.info("Opened System Settings application fallback")
            } else {
                logger.error("Failed to open System Settings application fallback")
            }
            return opened
        }

        logger.error("Failed to resolve any System Settings fallback")
        return false
    }

    @MainActor
    private func openSettingsURL(_ rawValue: String) -> Bool {
        guard let url = URL(string: rawValue) else {
            logger.error("Invalid System Settings URL: \(rawValue, privacy: .public)")
            return false
        }

        let opened = NSWorkspace.shared.open(url)
        if !opened {
            logger.warning("System Settings URL did not open: \(rawValue, privacy: .public)")
        }
        return opened
    }

    private func accessibilityOptions(prompt: Bool) -> CFDictionary {
        ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
    }
}
