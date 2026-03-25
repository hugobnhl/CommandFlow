import AppKit
import Foundation
import SwiftUI

enum BrowserPreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case systemDefault
    case safari
    case chrome
    case firefox
    case arc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemDefault:
            return "Default browser"
        case .safari:
            return "Safari"
        case .chrome:
            return "Chrome"
        case .firefox:
            return "Firefox"
        case .arc:
            return "Arc"
        }
    }

    var bundleID: String? {
        switch self {
        case .systemDefault:
            return nil
        case .safari:
            return "com.apple.Safari"
        case .chrome:
            return "com.google.Chrome"
        case .firefox:
            return "org.mozilla.firefox"
        case .arc:
            return "company.thebrowser.Browser"
        }
    }
}

enum MailPreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case systemDefault
    case appleMail
    case outlook
    case spark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemDefault:
            return "Default mail app"
        case .appleMail:
            return "Apple Mail"
        case .outlook:
            return "Outlook"
        case .spark:
            return "Spark"
        }
    }

    var bundleID: String? {
        switch self {
        case .systemDefault:
            return nil
        case .appleMail:
            return "com.apple.mail"
        case .outlook:
            return "com.microsoft.Outlook"
        case .spark:
            return "com.readdle.smartemail-Mac"
        }
    }
}

enum AccentThemeChoice: String, CaseIterable, Codable, Identifiable, Sendable {
    case guardianNavy
    case guardianBottleGreen
    case deepSlateBlue
    case softGraphite
    case mistSilverBlue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .guardianNavy:
            return "Guardian Navy"
        case .guardianBottleGreen:
            return "Guardian Bottle Green"
        case .deepSlateBlue:
            return "Deep Slate Blue"
        case .softGraphite:
            return "Soft Graphite"
        case .mistSilverBlue:
            return "Mist Silver Blue"
        }
    }
}

struct AccentPalette: Sendable {
    let accent: Color
    let accentSecondary: Color
    let glow: Color
    let softFill: Color
}

struct DensityMetrics: Sendable {
    let rowHeight: CGFloat
    let rowHorizontalPadding: CGFloat
    let rowVerticalPadding: CGFloat
    let controlVerticalPadding: CGFloat
    let sectionSpacing: CGFloat
    let stackSpacing: CGFloat
    let toolButtonVerticalPadding: CGFloat
}

enum DensityOption: String, CaseIterable, Codable, Identifiable, Sendable {
    case compact
    case normal
    case spacious

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact:
            return "Compact"
        case .normal:
            return "Normal"
        case .spacious:
            return "Spacious"
        }
    }

    var metrics: DensityMetrics {
        switch self {
        case .compact:
            return DensityMetrics(
                rowHeight: 36,
                rowHorizontalPadding: 8,
                rowVerticalPadding: 3,
                controlVerticalPadding: 7,
                sectionSpacing: 10,
                stackSpacing: 8,
                toolButtonVerticalPadding: 7
            )
        case .normal:
            return DensityMetrics(
                rowHeight: 41,
                rowHorizontalPadding: 9,
                rowVerticalPadding: 4,
                controlVerticalPadding: 8,
                sectionSpacing: 12,
                stackSpacing: 10,
                toolButtonVerticalPadding: 8
            )
        case .spacious:
            return DensityMetrics(
                rowHeight: 46,
                rowHorizontalPadding: 10,
                rowVerticalPadding: 6,
                controlVerticalPadding: 9,
                sectionSpacing: 14,
                stackSpacing: 12,
                toolButtonVerticalPadding: 9
            )
        }
    }
}

enum SavedURLSortOrder: String, CaseIterable, Codable, Identifiable, Sendable {
    case manual
    case recentlyAdded
    case recentlyUsed
    case alphabetical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual:
            return "Manual order"
        case .recentlyAdded:
            return "Most recently added"
        case .recentlyUsed:
            return "Most recently used"
        case .alphabetical:
            return "Alphabetical"
        }
    }
}

struct SavedURLItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var urlString: String
    let createdAt: Date
    var lastUsedAt: Date?
    var usageCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        createdAt: Date = .now,
        lastUsedAt: Date? = nil,
        usageCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.usageCount = usageCount
    }
}

struct QuickNoteItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var text: String
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), text: String, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ActionExecutionPreferences: Sendable {
    let preferredBrowser: BrowserPreference
    let preferredMailApp: MailPreference
}
