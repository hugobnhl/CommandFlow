import AppKit
import ApplicationServices
import Foundation

struct PermissionCenter: Sendable {
    func accessibilityGranted() -> Bool {
        AXIsProcessTrustedWithOptions(accessibilityOptions(prompt: false))
    }

    @MainActor
    func requestAccessibilityPrompt() {
        _ = AXIsProcessTrustedWithOptions(accessibilityOptions(prompt: true))
    }

    @MainActor
    func openAccessibilitySettings() {
        _ = openSettingsURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    @MainActor
    func openAutomationSettings() {
        if !openSettingsURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            _ = openSettingsURL("x-apple.systempreferences:com.apple.preference.security?Privacy")
        }
    }

    @MainActor
    private func openSettingsURL(_ rawValue: String) -> Bool {
        guard let url = URL(string: rawValue) else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }

    private func accessibilityOptions(prompt: Bool) -> CFDictionary {
        ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
    }
}
