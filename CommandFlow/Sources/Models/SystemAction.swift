import Foundation

enum ActionCategory: String, CaseIterable, Identifiable, Sendable {
    case quickLaunch = "Quick Launch"
    case workspace = "Workspace"
    case system = "System"
    case preferences = "Preferences"

    var id: String { rawValue }
}

enum ActionPermissionRequirement: String, Hashable, Sendable {
    case accessibility
    case automation
}

enum ActionCommand: Hashable, Sendable {
    case openPreferredMail
}

enum ActionTransport: Hashable, Sendable {
    case openApplication(bundleID: String)
    case openPath(String)
    case openURL(String)
    case shell(String)
    case appleScript(String)
    case command(ActionCommand)
}

struct SystemAction: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let detail: String
    let successMessage: String
    let systemImage: String
    let shortcut: String?
    let category: ActionCategory
    let keywords: [String]
    let transport: ActionTransport
    let permissionRequirement: ActionPermissionRequirement?
    let requiresConfirmation: Bool
    let isRecommended: Bool

    var searchableText: String {
        ([name, detail] + keywords).joined(separator: " ").lowercased()
    }
}

extension SystemAction {
    var usesFrontmostApplicationName: Bool {
        let ids: Set<String> = [
            "hide-front-app",
            "switch-window",
            "quit-app",
            "app-preferences",
            "close-window",
            "copy",
            "paste",
            "cut",
            "undo",
            "redo",
            "select-all",
            "find",
            "replace",
            "bold",
            "italic",
            "underline",
            "new-tab",
            "reload",
            "back",
            "forward",
            "focus-url",
            "full-screen",
            "minimize",
            "minimize-all",
            "zoom-in",
            "zoom-out",
        ]
        return ids.contains(id)
    }

    var requiresFrontmostApplicationContext: Bool {
        let ids: Set<String> = [
            "hide-front-app",
            "switch-window",
            "quit-app",
            "app-preferences",
            "close-window",
            "copy",
            "paste",
            "cut",
            "undo",
            "redo",
            "select-all",
            "find",
            "replace",
            "bold",
            "italic",
            "underline",
            "new-tab",
            "reload",
            "back",
            "forward",
            "focus-url",
            "full-screen",
            "minimize",
            "minimize-all",
            "zoom-in",
            "zoom-out",
        ]
        return ids.contains(id)
    }

    var requiresBrowserLikeApplication: Bool {
        let ids: Set<String> = [
            "new-tab",
            "reload",
            "back",
            "forward",
            "focus-url",
        ]
        return ids.contains(id)
    }

    var shouldRestoreFrontmostApplicationBeforeExecution: Bool {
        let ids: Set<String> = [
            "screenshot",
            "screenshot-full",
            "screenshot-selection",
            "spotlight",
            "switch-app",
            "switch-window",
            "force-quit",
            "hide-front-app",
            "quit-app",
            "app-preferences",
            "close-window",
            "copy",
            "paste",
            "cut",
            "undo",
            "redo",
            "select-all",
            "find",
            "replace",
            "bold",
            "italic",
            "underline",
            "new-tab",
            "reload",
            "back",
            "forward",
            "focus-url",
            "full-screen",
            "minimize",
            "minimize-all",
            "zoom-in",
            "zoom-out",
        ]
        return ids.contains(id)
    }

    var automationTargetBundleIdentifier: String? {
        switch id {
        case "empty-trash":
            return "com.apple.finder"
        case "toggle-dark-mode":
            return "com.apple.systemevents"
        default:
            return nil
        }
    }
}

private enum ActionScriptFactory {
    static func systemEventsKeystroke(_ key: String, modifiers: [String] = []) -> String {
        """
        tell application "System Events"
            keystroke "\(key)"\(modifierSuffix(modifiers))
        end tell
        """
    }

    static func systemEventsKeyCode(_ keyCode: Int, modifiers: [String] = []) -> String {
        """
        tell application "System Events"
            key code \(keyCode)\(modifierSuffix(modifiers))
        end tell
        """
    }

    static func appKeystroke(_ appName: String, key: String, modifiers: [String] = []) -> String {
        """
        tell application "\(appName)"
            activate
        end tell
        delay 0.08
        tell application "System Events"
            keystroke "\(key)"\(modifierSuffix(modifiers))
        end tell
        """
    }

    static func appKeyCode(_ appName: String, keyCode: Int, modifiers: [String] = []) -> String {
        """
        tell application "\(appName)"
            activate
        end tell
        delay 0.08
        tell application "System Events"
            key code \(keyCode)\(modifierSuffix(modifiers))
        end tell
        """
    }

    private static func modifierSuffix(_ modifiers: [String]) -> String {
        guard !modifiers.isEmpty else {
            return ""
        }

        return " using {" + modifiers.joined(separator: ", ") + "}"
    }
}

enum ActionCatalog {
    static let defaultQuickActionIDs = [
        "finder",
        "safari",
        "terminal",
        "empty-trash",
    ]

    static let all: [SystemAction] = [
        SystemAction(
            id: "finder",
            name: "Open Finder",
            detail: "Jump straight into a Finder window.",
            successMessage: "Finder opened.",
            systemImage: "folder",
            shortcut: nil,
            category: .quickLaunch,
            keywords: ["files", "browse", "finder"],
            transport: .openApplication(bundleID: "com.apple.finder"),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: true
        ),
        SystemAction(
            id: "safari",
            name: "Open Safari",
            detail: "Launch Safari instantly.",
            successMessage: "Safari opened.",
            systemImage: "safari",
            shortcut: nil,
            category: .quickLaunch,
            keywords: ["browser", "web", "internet"],
            transport: .openApplication(bundleID: "com.apple.Safari"),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: true
        ),
        SystemAction(
            id: "terminal",
            name: "Open Terminal",
            detail: "Open a fresh Terminal session.",
            successMessage: "Terminal opened.",
            systemImage: "terminal",
            shortcut: nil,
            category: .quickLaunch,
            keywords: ["shell", "command line", "cli"],
            transport: .openApplication(bundleID: "com.apple.Terminal"),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: true
        ),
        SystemAction(
            id: "mail",
            name: "Open Mail",
            detail: "Launch your preferred mail app.",
            successMessage: "Mail app opened.",
            systemImage: "envelope",
            shortcut: nil,
            category: .quickLaunch,
            keywords: ["mail", "email", "inbox", "outlook", "spark"],
            transport: .command(.openPreferredMail),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: true
        ),
        SystemAction(
            id: "downloads",
            name: "Open Downloads",
            detail: "Reveal your Downloads folder.",
            successMessage: "Downloads opened.",
            systemImage: "arrow.down.circle",
            shortcut: nil,
            category: .workspace,
            keywords: ["files", "folder", "downloads"],
            transport: .openPath("~/Downloads"),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: true
        ),
        SystemAction(
            id: "applications",
            name: "Open Applications",
            detail: "Jump to the Applications folder.",
            successMessage: "Applications folder opened.",
            systemImage: "square.grid.2x2",
            shortcut: nil,
            category: .workspace,
            keywords: ["apps", "folder", "launch"],
            transport: .openPath("/Applications"),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "clock-timer",
            name: "Set a Timer",
            detail: "Open Clock so you can jump into a timer quickly.",
            successMessage: "Clock opened.",
            systemImage: "timer",
            shortcut: nil,
            category: .workspace,
            keywords: ["timer", "clock", "countdown", "alarm"],
            transport: .openApplication(bundleID: "com.apple.clock"),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: true
        ),
        SystemAction(
            id: "activity-monitor",
            name: "Open Activity Monitor",
            detail: "Check processes and system load.",
            successMessage: "Activity Monitor opened.",
            systemImage: "waveform.path.ecg",
            shortcut: nil,
            category: .workspace,
            keywords: ["cpu", "memory", "monitor", "processes"],
            transport: .openApplication(bundleID: "com.apple.ActivityMonitor"),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "spotify",
            name: "Open Spotify",
            detail: "Jump into Spotify instantly.",
            successMessage: "Spotify opened.",
            systemImage: "music.note.list",
            shortcut: nil,
            category: .workspace,
            keywords: ["spotify", "music", "audio", "playlist"],
            transport: .openApplication(bundleID: "com.spotify.client"),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: true
        ),
        SystemAction(
            id: "apple-music",
            name: "Open Apple Music",
            detail: "Launch Apple Music immediately.",
            successMessage: "Music opened.",
            systemImage: "music.note",
            shortcut: nil,
            category: .workspace,
            keywords: ["apple music", "music", "audio", "songs"],
            transport: .openApplication(bundleID: "com.apple.Music"),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: true
        ),
        SystemAction(
            id: "screenshot",
            name: "Screenshot Tool",
            detail: "Open the native screenshot palette.",
            successMessage: "Screenshot tool opened.",
            systemImage: "camera.viewfinder",
            shortcut: "⇧⌘5",
            category: .workspace,
            keywords: ["capture", "screen", "record", "screenshot tool"],
            transport: .openApplication(bundleID: "com.apple.screenshot.launcher"),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "spotlight",
            name: "Spotlight",
            detail: "Trigger the system search overlay.",
            successMessage: "Spotlight triggered.",
            systemImage: "magnifyingglass",
            shortcut: "⌘Space",
            category: .workspace,
            keywords: ["search", "launcher", "spotlight"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeyCode(49, modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: true
        ),
        SystemAction(
            id: "hide-front-app",
            name: "Hide Frontmost App",
            detail: "Send the active app behind the glass.",
            successMessage: "Frontmost app hidden.",
            systemImage: "rectangle.portrait.and.arrow.right",
            shortcut: "⌘H",
            category: .workspace,
            keywords: ["hide", "foreground", "window"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("h", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "switch-app",
            name: "Switch App",
            detail: "Show the app switcher and move to the next app.",
            successMessage: "App switcher opened.",
            systemImage: "square.on.square.intersection.dashed",
            shortcut: "⌘Tab",
            category: .workspace,
            keywords: ["switch app", "tab", "launcher", "app switcher"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeyCode(48, modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: true
        ),
        SystemAction(
            id: "switch-window",
            name: "Switch Window",
            detail: "Cycle through windows in the active app.",
            successMessage: "Window switch triggered.",
            systemImage: "macwindow.on.rectangle",
            shortcut: "⇧⌘~",
            category: .workspace,
            keywords: ["switch window", "cycle", "window"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeyCode(50, modifiers: ["shift down", "command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "quit-app",
            name: "Quit App",
            detail: "Quit the frontmost app.",
            successMessage: "Quit command sent.",
            systemImage: "xmark.app",
            shortcut: "⌘Q",
            category: .workspace,
            keywords: ["quit", "close app", "frontmost"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("q", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "app-preferences",
            name: "Preferences",
            detail: "Open the frontmost app preferences window.",
            successMessage: "Preferences command sent.",
            systemImage: "slider.horizontal.3",
            shortcut: "⌘,",
            category: .workspace,
            keywords: ["preferences", "settings", "app settings"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke(",", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "emoji-picker",
            name: "Emoji Picker",
            detail: "Open the character and emoji picker.",
            successMessage: "Emoji picker opened.",
            systemImage: "face.smiling",
            shortcut: "⌃⌘Space",
            category: .workspace,
            keywords: ["emoji", "symbols", "character viewer"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeyCode(49, modifiers: ["control down", "command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "new-folder",
            name: "New Folder",
            detail: "Create a new folder in Finder.",
            successMessage: "New folder command sent to Finder.",
            systemImage: "folder.badge.plus",
            shortcut: "⇧⌘N",
            category: .workspace,
            keywords: ["finder", "new folder", "files"],
            transport: .appleScript(ActionScriptFactory.appKeystroke("Finder", key: "n", modifiers: ["shift down", "command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "open-file",
            name: "Open File",
            detail: "Send the Open command to Finder.",
            successMessage: "Open command sent to Finder.",
            systemImage: "doc",
            shortcut: "⌘O",
            category: .workspace,
            keywords: ["finder", "open file", "open"],
            transport: .appleScript(ActionScriptFactory.appKeystroke("Finder", key: "o", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "close-window",
            name: "Close Window",
            detail: "Close the frontmost window.",
            successMessage: "Close window command sent.",
            systemImage: "xmark.square",
            shortcut: "⌘W",
            category: .workspace,
            keywords: ["close window", "window", "dismiss"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("w", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "duplicate-file",
            name: "Duplicate File",
            detail: "Duplicate the Finder selection.",
            successMessage: "Duplicate command sent to Finder.",
            systemImage: "plus.square.on.square",
            shortcut: "⌘D",
            category: .workspace,
            keywords: ["duplicate", "finder", "copy file"],
            transport: .appleScript(ActionScriptFactory.appKeystroke("Finder", key: "d", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "delete-file",
            name: "Delete File",
            detail: "Move the Finder selection to Trash.",
            successMessage: "Delete command sent to Finder.",
            systemImage: "delete.left",
            shortcut: "⌘Delete",
            category: .workspace,
            keywords: ["delete", "finder", "trash"],
            transport: .appleScript(ActionScriptFactory.appKeyCode("Finder", keyCode: 51, modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: true,
            isRecommended: false
        ),
        SystemAction(
            id: "empty-trash",
            name: "Empty Trash",
            detail: "Ask Finder to empty the Trash.",
            successMessage: "Trash emptied.",
            systemImage: "trash",
            shortcut: "⇧⌘Delete",
            category: .system,
            keywords: ["delete", "remove", "clean"],
            transport: .appleScript("""
            tell application "Finder"
                empty the trash
            end tell
            """),
            permissionRequirement: .automation,
            requiresConfirmation: true,
            isRecommended: true
        ),
        SystemAction(
            id: "empty-trash-force",
            name: "Empty Trash (Force)",
            detail: "Force empty Trash from Finder.",
            successMessage: "Force empty Trash command sent.",
            systemImage: "trash.slash",
            shortcut: "⌥⇧⌘Delete",
            category: .system,
            keywords: ["trash", "force", "delete", "clean"],
            transport: .appleScript(ActionScriptFactory.appKeyCode("Finder", keyCode: 51, modifiers: ["option down", "shift down", "command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: true,
            isRecommended: false
        ),
        SystemAction(
            id: "toggle-dark-mode",
            name: "Toggle Dark Mode",
            detail: "Flip the system appearance instantly.",
            successMessage: "Appearance toggled.",
            systemImage: "circle.lefthalf.filled",
            shortcut: nil,
            category: .system,
            keywords: ["appearance", "theme", "light", "dark"],
            transport: .appleScript("""
            tell application "System Events"
                tell appearance preferences
                    set dark mode to not dark mode
                end tell
            end tell
            """),
            permissionRequirement: .automation,
            requiresConfirmation: false,
            isRecommended: true
        ),
        SystemAction(
            id: "lock-screen",
            name: "Lock Screen",
            detail: "Suspend the session and show the lock screen.",
            successMessage: "Mac locked.",
            systemImage: "lock.circle",
            shortcut: "⌃⌘Q",
            category: .system,
            keywords: ["secure", "privacy", "screen"],
            transport: .shell("\"/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession\" -suspend"),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: true
        ),
        SystemAction(
            id: "force-quit",
            name: "Force Quit",
            detail: "Open the Force Quit Applications window.",
            successMessage: "Force Quit window opened.",
            systemImage: "exclamationmark.octagon",
            shortcut: "⌥⌘Esc",
            category: .system,
            keywords: ["force quit", "quit", "app"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeyCode(53, modifiers: ["option down", "command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: true
        ),
        SystemAction(
            id: "copy",
            name: "Copy",
            detail: "Copy the current selection.",
            successMessage: "Copy command sent.",
            systemImage: "doc.on.doc",
            shortcut: "⌘C",
            category: .workspace,
            keywords: ["copy", "clipboard", "text"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("c", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "paste",
            name: "Paste",
            detail: "Paste from the clipboard.",
            successMessage: "Paste command sent.",
            systemImage: "doc.on.clipboard",
            shortcut: "⌘V",
            category: .workspace,
            keywords: ["paste", "clipboard", "text"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("v", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "cut",
            name: "Cut",
            detail: "Cut the current selection.",
            successMessage: "Cut command sent.",
            systemImage: "scissors",
            shortcut: "⌘X",
            category: .workspace,
            keywords: ["cut", "clipboard", "text"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("x", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "undo",
            name: "Undo",
            detail: "Undo the most recent edit.",
            successMessage: "Undo command sent.",
            systemImage: "arrow.uturn.backward",
            shortcut: "⌘Z",
            category: .workspace,
            keywords: ["undo", "edit", "text"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("z", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "redo",
            name: "Redo",
            detail: "Redo the latest undone edit.",
            successMessage: "Redo command sent.",
            systemImage: "arrow.uturn.forward",
            shortcut: "⇧⌘Z",
            category: .workspace,
            keywords: ["redo", "edit", "text"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("z", modifiers: ["shift down", "command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "select-all",
            name: "Select All",
            detail: "Select everything in the frontmost view.",
            successMessage: "Select All command sent.",
            systemImage: "selection.pin.in.out",
            shortcut: "⌘A",
            category: .workspace,
            keywords: ["select all", "selection", "text"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("a", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "find",
            name: "Find",
            detail: "Open the Find interface.",
            successMessage: "Find command sent.",
            systemImage: "magnifyingglass.circle",
            shortcut: "⌘F",
            category: .workspace,
            keywords: ["find", "search", "text"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("f", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "replace",
            name: "Replace",
            detail: "Open Replace in the frontmost app.",
            successMessage: "Replace command sent.",
            systemImage: "rectangle.and.pencil.and.ellipsis",
            shortcut: "⌥⌘F",
            category: .workspace,
            keywords: ["replace", "find", "text"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("f", modifiers: ["option down", "command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "bold",
            name: "Bold",
            detail: "Toggle bold formatting.",
            successMessage: "Bold command sent.",
            systemImage: "bold",
            shortcut: "⌘B",
            category: .workspace,
            keywords: ["bold", "format", "text"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("b", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "italic",
            name: "Italic",
            detail: "Toggle italic formatting.",
            successMessage: "Italic command sent.",
            systemImage: "italic",
            shortcut: "⌘I",
            category: .workspace,
            keywords: ["italic", "format", "text"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("i", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "underline",
            name: "Underline",
            detail: "Toggle underline formatting.",
            successMessage: "Underline command sent.",
            systemImage: "underline",
            shortcut: "⌘U",
            category: .workspace,
            keywords: ["underline", "format", "text"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("u", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "new-tab",
            name: "New Tab",
            detail: "Open a new tab in the frontmost app.",
            successMessage: "New Tab command sent.",
            systemImage: "plus.rectangle.on.rectangle",
            shortcut: "⌘T",
            category: .workspace,
            keywords: ["new tab", "tab", "browser"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("t", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "reload",
            name: "Reload",
            detail: "Reload the current page or document.",
            successMessage: "Reload command sent.",
            systemImage: "arrow.clockwise",
            shortcut: "⌘R",
            category: .workspace,
            keywords: ["reload", "refresh", "browser"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("r", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "back",
            name: "Back",
            detail: "Navigate backward in the frontmost app.",
            successMessage: "Back command sent.",
            systemImage: "chevron.backward",
            shortcut: "⌘[",
            category: .workspace,
            keywords: ["back", "previous", "navigation"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("[", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "forward",
            name: "Forward",
            detail: "Navigate forward in the frontmost app.",
            successMessage: "Forward command sent.",
            systemImage: "chevron.forward",
            shortcut: "⌘]",
            category: .workspace,
            keywords: ["forward", "next", "navigation"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("]", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "focus-url",
            name: "Focus URL",
            detail: "Focus the location bar in browser-style apps.",
            successMessage: "Focus URL command sent.",
            systemImage: "link",
            shortcut: "⌘L",
            category: .workspace,
            keywords: ["url", "location bar", "browser", "address"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("l", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "full-screen",
            name: "Full Screen",
            detail: "Toggle full screen for the frontmost window.",
            successMessage: "Full Screen command sent.",
            systemImage: "arrow.up.left.and.arrow.down.right",
            shortcut: "⌃⌘F",
            category: .workspace,
            keywords: ["full screen", "window", "display"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("f", modifiers: ["control down", "command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "minimize",
            name: "Minimize",
            detail: "Minimize the frontmost window.",
            successMessage: "Minimize command sent.",
            systemImage: "minus.rectangle",
            shortcut: "⌘M",
            category: .workspace,
            keywords: ["minimize", "window", "hide"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("m", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "minimize-all",
            name: "Minimize All",
            detail: "Minimize all windows for the frontmost app.",
            successMessage: "Minimize All command sent.",
            systemImage: "rectangle.compress.vertical",
            shortcut: "⌥⌘M",
            category: .workspace,
            keywords: ["minimize all", "windows", "app"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("m", modifiers: ["option down", "command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "zoom-in",
            name: "Zoom In",
            detail: "Increase the zoom level.",
            successMessage: "Zoom In command sent.",
            systemImage: "plus.magnifyingglass",
            shortcut: "⌘=",
            category: .workspace,
            keywords: ["zoom in", "scale", "window"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("=", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "zoom-out",
            name: "Zoom Out",
            detail: "Decrease the zoom level.",
            successMessage: "Zoom Out command sent.",
            systemImage: "minus.magnifyingglass",
            shortcut: "⌘-",
            category: .workspace,
            keywords: ["zoom out", "scale", "window"],
            transport: .appleScript(ActionScriptFactory.systemEventsKeystroke("-", modifiers: ["command down"])),
            permissionRequirement: .accessibility,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "screenshot-full",
            name: "Screenshot Full",
            detail: "Capture the full screen to your Desktop.",
            successMessage: "Full screen capture started.",
            systemImage: "rectangle.on.rectangle",
            shortcut: "⇧⌘3",
            category: .system,
            keywords: ["screenshot", "screen", "capture"],
            transport: .shell("/usr/sbin/screencapture -x \"$HOME/Desktop/CommandFlow-$(date +%Y%m%d-%H%M%S).png\""),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "screenshot-selection",
            name: "Screenshot Selection",
            detail: "Capture a selected region to your Desktop.",
            successMessage: "Selection capture started.",
            systemImage: "selection.pin.in.out",
            shortcut: "⇧⌘4",
            category: .system,
            keywords: ["screenshot", "selection", "capture"],
            transport: .shell("/usr/sbin/screencapture -i \"$HOME/Desktop/CommandFlow-$(date +%Y%m%d-%H%M%S).png\""),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "mute",
            name: "Mute",
            detail: "Toggle output mute.",
            successMessage: "Mute setting updated.",
            systemImage: "speaker.slash",
            shortcut: "F10",
            category: .system,
            keywords: ["mute", "audio", "sound", "volume"],
            transport: .appleScript("""
            set currentSettings to get volume settings
            if output muted of currentSettings is true then
                set volume without output muted
            else
                set volume with output muted
            end if
            """),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "volume-down",
            name: "Volume Down",
            detail: "Lower output volume.",
            successMessage: "Volume lowered.",
            systemImage: "speaker.minus",
            shortcut: "F11",
            category: .system,
            keywords: ["volume down", "audio", "sound"],
            transport: .appleScript("""
            set currentSettings to get volume settings
            set currentVolume to output volume of currentSettings
            set newVolume to currentVolume - 6
            if newVolume < 0 then set newVolume to 0
            set volume output volume newVolume without output muted
            """),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "volume-up",
            name: "Volume Up",
            detail: "Raise output volume.",
            successMessage: "Volume increased.",
            systemImage: "speaker.plus",
            shortcut: "F12",
            category: .system,
            keywords: ["volume up", "audio", "sound"],
            transport: .appleScript("""
            set currentSettings to get volume settings
            set currentVolume to output volume of currentSettings
            set newVolume to currentVolume + 6
            if newVolume > 100 then set newVolume to 100
            set volume output volume newVolume without output muted
            """),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "sleep",
            name: "Sleep Mac",
            detail: "Put the Mac to sleep immediately.",
            successMessage: "Mac is going to sleep.",
            systemImage: "moon.zzz",
            shortcut: nil,
            category: .system,
            keywords: ["sleep", "energy", "power"],
            transport: .shell("/usr/bin/pmset sleepnow"),
            permissionRequirement: nil,
            requiresConfirmation: true,
            isRecommended: false
        ),
        SystemAction(
            id: "screen-saver",
            name: "Start Screen Saver",
            detail: "Launch the current screen saver right away.",
            successMessage: "Screen saver started.",
            systemImage: "sparkles.tv",
            shortcut: nil,
            category: .system,
            keywords: ["idle", "screen saver", "display"],
            transport: .shell("open -a ScreenSaverEngine"),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "system-settings",
            name: "Open System Settings",
            detail: "Jump into macOS settings.",
            successMessage: "System Settings opened.",
            systemImage: "gearshape",
            shortcut: nil,
            category: .preferences,
            keywords: ["preferences", "settings", "system"],
            transport: .openApplication(bundleID: "com.apple.systempreferences"),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: true
        ),
        SystemAction(
            id: "bluetooth-settings",
            name: "Open Bluetooth Settings",
            detail: "Reveal the Bluetooth settings pane.",
            successMessage: "Bluetooth settings opened.",
            systemImage: "bolt.horizontal.circle",
            shortcut: nil,
            category: .preferences,
            keywords: ["bluetooth", "devices", "settings"],
            transport: .openURL("x-apple.systempreferences:com.apple.BluetoothSettings"),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "display-settings",
            name: "Open Display Settings",
            detail: "Jump to display configuration.",
            successMessage: "Display settings opened.",
            systemImage: "display.2",
            shortcut: nil,
            category: .preferences,
            keywords: ["screen", "display", "brightness"],
            transport: .openURL("x-apple.systempreferences:com.apple.Displays-Settings.extension"),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: false
        ),
        SystemAction(
            id: "network-settings",
            name: "Open Network Settings",
            detail: "Open the network preferences pane.",
            successMessage: "Network settings opened.",
            systemImage: "network",
            shortcut: nil,
            category: .preferences,
            keywords: ["wifi", "ethernet", "network"],
            transport: .openURL("x-apple.systempreferences:com.apple.Network-Settings.extension"),
            permissionRequirement: nil,
            requiresConfirmation: false,
            isRecommended: false
        ),
    ]
}
