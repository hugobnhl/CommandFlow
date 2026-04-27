import AppKit
import ApplicationServices
import Foundation
import IOKit.hidsystem
import OSLog

enum AutomationPermissionSummary: String, Equatable, Sendable {
    case granted
    case partiallyGranted
    case requiresConsent
    case denied
    case unknown
}

enum AutomationTargetPermissionState: Equatable, Sendable {
    case granted
    case requiresConsent
    case denied
    case targetNotRunning
    case unknown(OSStatus)

    var isGranted: Bool {
        if case .granted = self {
            return true
        }
        return false
    }
}

struct AutomationPermissionSnapshot: Equatable, Sendable {
    let finder: AutomationTargetPermissionState
    let systemEvents: AutomationTargetPermissionState

    var summary: AutomationPermissionSummary {
        let states = [finder, systemEvents]

        if states.allSatisfy(\.isGranted) {
            return .granted
        }

        if states.contains(where: \.isGranted) {
            return .partiallyGranted
        }

        if states.contains(.denied) {
            return .denied
        }

        if states.contains(.requiresConsent) {
            return .requiresConsent
        }

        return .unknown
    }

    var hasAnyGrantedTarget: Bool {
        finder.isGranted || systemEvents.isGranted
    }
}

struct InputMonitoringRequestResult: Equatable, Sendable {
    let cgGrantedBeforeRequest: Bool
    let hidAccessBeforeRequest: InputMonitoringAccessState
    let cgApiReportedGranted: Bool
    let hidApiReportedGranted: Bool
    let eventTapProbeSucceeded: Bool
    let isGrantedAfterRequest: Bool
}

enum InputMonitoringAccessState: String, Equatable, Sendable {
    case granted
    case denied
    case unknown
}

struct PermissionCenter: Sendable {
    private enum AutomationTarget: CaseIterable {
        case finder
        case systemEvents

        var bundleIdentifier: String {
            switch self {
            case .finder:
                return "com.apple.finder"
            case .systemEvents:
                return "com.apple.systemevents"
            }
        }

        var displayName: String {
            switch self {
            case .finder:
                return "Finder"
            case .systemEvents:
                return "System Events"
            }
        }

        var promptScript: String {
            switch self {
            case .finder:
                return """
                tell application "Finder"
                    get name of startup disk
                end tell
                """
            case .systemEvents:
                return """
                tell application "System Events"
                    get name of current user
                end tell
                """
            }
        }
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.hugobrun.commandflow.dev",
        category: "permissions"
    )

    func accessibilityGranted() -> Bool {
        AXIsProcessTrustedWithOptions(accessibilityOptions(prompt: false))
    }

    func inputMonitoringGranted() -> Bool {
        CGPreflightListenEventAccess() || inputMonitoringAccessState() == .granted
    }

    func inputMonitoringAccessState() -> InputMonitoringAccessState {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            return .granted
        case kIOHIDAccessTypeDenied:
            return .denied
        default:
            return .unknown
        }
    }

    func automationPermissionSnapshot() -> AutomationPermissionSnapshot {
        AutomationPermissionSnapshot(
            finder: automationPermissionState(for: .finder),
            systemEvents: automationPermissionState(for: .systemEvents)
        )
    }

    @MainActor
    func requestAccessibilityPrompt() {
        logger.info("Requesting accessibility permission prompt")
        _ = AXIsProcessTrustedWithOptions(accessibilityOptions(prompt: true))
    }

    @MainActor
    func requestInputMonitoringPrompt() -> InputMonitoringRequestResult {
        NSApp.activate(ignoringOtherApps: true)

        let cgGrantedBeforeRequest = CGPreflightListenEventAccess()
        let hidAccessBeforeRequest = inputMonitoringAccessState()
        logger.info(
            """
            Requesting input monitoring permission prompt; \
            cgGrantedBeforeRequest: \(cgGrantedBeforeRequest), \
            hidAccessBeforeRequest: \(hidAccessBeforeRequest.rawValue, privacy: .public)
            """
        )

        let cgApiReportedGranted = CGRequestListenEventAccess()
        let hidApiReportedGranted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        let eventTapProbeSucceeded = createInputMonitoringProbeTap()
        let isGrantedAfterRequest = inputMonitoringGranted() || eventTapProbeSucceeded

        logger.info(
            """
            Input monitoring request completed; \
            cgApiReportedGranted: \(cgApiReportedGranted), \
            hidApiReportedGranted: \(hidApiReportedGranted), \
            eventTapProbeSucceeded: \(eventTapProbeSucceeded), \
            isGrantedAfterRequest: \(isGrantedAfterRequest)
            """
        )

        return InputMonitoringRequestResult(
            cgGrantedBeforeRequest: cgGrantedBeforeRequest,
            hidAccessBeforeRequest: hidAccessBeforeRequest,
            cgApiReportedGranted: cgApiReportedGranted,
            hidApiReportedGranted: hidApiReportedGranted,
            eventTapProbeSucceeded: eventTapProbeSucceeded,
            isGrantedAfterRequest: isGrantedAfterRequest
        )
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
    func openInputMonitoringSettings() {
        NSApp.activate(ignoringOtherApps: true)
        _ = openSettingsURLs([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.preference.security?Privacy",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
        ])
    }

    @MainActor
    func requestAutomationPrompt() {
        let snapshot = automationPermissionSnapshot()
        let targetsToRequest = AutomationTarget.allCases.filter { target in
            switch target {
            case .finder:
                return snapshot.finder != .granted
            case .systemEvents:
                return snapshot.systemEvents != .granted
            }
        }

        guard !targetsToRequest.isEmpty else {
            logger.info("Automation request skipped because all tracked targets are already granted")
            return
        }

        for target in targetsToRequest {
            requestAutomationPrompt(for: target)
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

    private func createInputMonitoringProbeTap() -> Bool {
        let eventMask = CGEventMask(1) << CGEventType.keyDown.rawValue

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: Self.inputMonitoringProbeCallback,
            userInfo: nil
        ) else {
            logger.warning("Input monitoring probe tap could not be created")
            return false
        }

        logger.info("Input monitoring probe tap created successfully")
        CFMachPortInvalidate(tap)
        return true
    }

    private static let inputMonitoringProbeCallback: CGEventTapCallBack = { _, _, event, _ in
        Unmanaged.passUnretained(event)
    }

    private func requestAutomationPrompt(for target: AutomationTarget) {
        logger.info("Requesting automation permission prompt through \(target.displayName, privacy: .public)")

        guard let script = NSAppleScript(source: target.promptScript) else {
            logger.error("Failed to create automation prompt AppleScript for \(target.displayName, privacy: .public)")
            return
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            logger.warning("Automation prompt for \(target.displayName, privacy: .public) returned: \(message, privacy: .public)")
        } else {
            logger.info("Automation prompt for \(target.displayName, privacy: .public) executed successfully")
        }
    }

    private func automationPermissionState(for target: AutomationTarget) -> AutomationTargetPermissionState {
        let runningApplications = NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleIdentifier)
        guard !runningApplications.isEmpty else {
            logger.debug("Automation probe for \(target.displayName, privacy: .public) skipped because the app is not running")
            return .targetNotRunning
        }

        let bundleIDData = Data(target.bundleIdentifier.utf8)
        var addressDescriptor = AEAddressDesc()
        let createStatus = bundleIDData.withUnsafeBytes { buffer in
            AECreateDesc(
                DescType(typeApplicationBundleID),
                buffer.baseAddress,
                buffer.count,
                &addressDescriptor
            )
        }

        guard createStatus == noErr else {
            logger.error("Failed to create AppleEvent descriptor for \(target.displayName, privacy: .public): \(createStatus)")
            return .unknown(OSStatus(createStatus))
        }

        defer {
            AEDisposeDesc(&addressDescriptor)
        }

        let probeStatus = AEDeterminePermissionToAutomateTarget(
            &addressDescriptor,
            AEEventClass(typeWildCard),
            AEEventID(typeWildCard),
            false
        )

        switch probeStatus {
        case noErr:
            return .granted
        case OSStatus(errAEEventWouldRequireUserConsent):
            return .requiresConsent
        case OSStatus(errAEEventNotPermitted):
            return .denied
        case OSStatus(procNotFound):
            return .targetNotRunning
        default:
            logger.warning(
                "Automation probe for \(target.displayName, privacy: .public) returned unexpected status: \(probeStatus)"
            )
            return .unknown(probeStatus)
        }
    }
}
