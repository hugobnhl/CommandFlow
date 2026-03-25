import AppKit
import Foundation

struct ActionExecutionOutcome: Sendable {
    let title: String
    let detail: String
}

enum ActionExecutionError: LocalizedError, Sendable {
    case missingPermission(ActionPermissionRequirement)
    case applicationNotFound(String)
    case invalidURL(String)
    case scriptFailed(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingPermission(.accessibility):
            return "Accessibility access is required for that action."
        case .missingPermission(.automation):
            return "macOS blocked automation for that action."
        case .applicationNotFound(let identifier):
            return "The app for \(identifier) could not be found."
        case .invalidURL(let rawValue):
            return "The destination \(rawValue) is not a valid URL."
        case .scriptFailed(let message):
            return message
        case .commandFailed(let message):
            return message
        }
    }
}

struct SystemActionPerformer: Sendable {
    private let permissionCenter: PermissionCenter
    private let applicationRouter: ApplicationRouter

    init(permissionCenter: PermissionCenter, applicationRouter: ApplicationRouter) {
        self.permissionCenter = permissionCenter
        self.applicationRouter = applicationRouter
    }

    func execute(_ action: SystemAction, preferences: ActionExecutionPreferences) async throws -> ActionExecutionOutcome {
        if action.permissionRequirement == .accessibility, !permissionCenter.accessibilityGranted() {
            throw ActionExecutionError.missingPermission(.accessibility)
        }

        switch action.transport {
        case .openApplication(let bundleID):
            try await applicationRouter.openApplication(bundleID: bundleID)
        case .openPath(let path):
            try await openPath(path)
        case .openURL(let rawValue):
            try await openURL(rawValue, browserPreference: preferences.preferredBrowser)
        case .shell(let command):
            try await runShell(command)
        case .appleScript(let source):
            try await runAppleScript(source)
        case .command(.openPreferredMail):
            try await applicationRouter.openMail(preference: preferences.preferredMailApp)
        }

        return ActionExecutionOutcome(title: action.name, detail: action.successMessage)
    }

    @MainActor
    private func openPath(_ rawPath: String) throws {
        let expandedPath = NSString(string: rawPath).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        guard NSWorkspace.shared.open(url) else {
            throw ActionExecutionError.commandFailed("macOS could not open \(expandedPath).")
        }
    }

    @MainActor
    private func openURL(_ rawValue: String, browserPreference: BrowserPreference) async throws {
        guard let url = URL(string: rawValue) else {
            throw ActionExecutionError.invalidURL(rawValue)
        }

        if let scheme = url.scheme?.lowercased(), scheme != "http", scheme != "https" {
            guard NSWorkspace.shared.open(url) else {
                throw ActionExecutionError.commandFailed("macOS could not open that destination.")
            }
            return
        }

        try await applicationRouter.openURL(url, preference: browserPreference)
    }

    private func runShell(_ command: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]
            process.standardOutput = stdout
            process.standardError = stderr

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let standardOutput = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let message = (errorOutput?.isEmpty == false ? errorOutput : standardOutput) ?? "The command did not complete."
                throw ActionExecutionError.commandFailed(message)
            }
        }.value
    }

    @MainActor
    private func runAppleScript(_ source: String) throws {
        guard let script = NSAppleScript(source: source) else {
            throw ActionExecutionError.scriptFailed("The action script could not be created.")
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)

        guard let errorInfo else {
            return
        }

        throw Self.mapAppleScriptError(errorInfo)
    }

    private static func mapAppleScriptError(_ info: NSDictionary) -> ActionExecutionError {
        let number = info[NSAppleScript.errorNumber] as? Int ?? 0
        let message = info[NSAppleScript.errorMessage] as? String ?? "The action could not complete."
        let lowercasedMessage = message.lowercased()

        if number == -1719 || lowercasedMessage.contains("assistive access") {
            return .missingPermission(.accessibility)
        }

        if number == -1743 || lowercasedMessage.contains("not authorized") || lowercasedMessage.contains("automation") {
            return .missingPermission(.automation)
        }

        return .scriptFailed(message)
    }
}
