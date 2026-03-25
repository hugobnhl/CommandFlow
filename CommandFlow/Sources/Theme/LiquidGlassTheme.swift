import SwiftUI

enum LiquidGlassTheme {
    static let panelRadius: CGFloat = 26
    static let sectionRadius: CGFloat = 20
    static let controlRadius: CGFloat = 14
    static let rowRadius: CGFloat = 14
    static let chipRadius: CGFloat = 16
    static let menuWidth: CGFloat = 430
    static let menuHeight: CGFloat = 640

    static let panelSpring = Animation.spring(response: 0.42, dampingFraction: 0.82)
    static let rowSpring = Animation.spring(response: 0.28, dampingFraction: 0.86)

    static func shadowColor(for scheme: ColorScheme) -> Color {
        Color.black.opacity(scheme == .dark ? 0.22 : 0.1)
    }

    static func palette(for choice: AccentThemeChoice) -> AccentPalette {
        switch choice {
        case .guardianNavy:
            return AccentPalette(
                accent: Color(red: 0.50, green: 0.69, blue: 0.96),
                accentSecondary: Color(red: 0.66, green: 0.80, blue: 1.0),
                glow: Color(red: 0.49, green: 0.68, blue: 0.95),
                softFill: Color(red: 0.26, green: 0.34, blue: 0.49)
            )
        case .guardianBottleGreen:
            return AccentPalette(
                accent: Color(red: 0.43, green: 0.67, blue: 0.56),
                accentSecondary: Color(red: 0.63, green: 0.82, blue: 0.73),
                glow: Color(red: 0.40, green: 0.63, blue: 0.53),
                softFill: Color(red: 0.24, green: 0.33, blue: 0.29)
            )
        case .deepSlateBlue:
            return AccentPalette(
                accent: Color(red: 0.43, green: 0.56, blue: 0.84),
                accentSecondary: Color(red: 0.62, green: 0.70, blue: 0.93),
                glow: Color(red: 0.41, green: 0.54, blue: 0.82),
                softFill: Color(red: 0.24, green: 0.28, blue: 0.40)
            )
        case .softGraphite:
            return AccentPalette(
                accent: Color(red: 0.60, green: 0.63, blue: 0.69),
                accentSecondary: Color(red: 0.77, green: 0.79, blue: 0.84),
                glow: Color(red: 0.58, green: 0.61, blue: 0.68),
                softFill: Color(red: 0.31, green: 0.33, blue: 0.36)
            )
        case .mistSilverBlue:
            return AccentPalette(
                accent: Color(red: 0.57, green: 0.72, blue: 0.86),
                accentSecondary: Color(red: 0.77, green: 0.86, blue: 0.95),
                glow: Color(red: 0.55, green: 0.70, blue: 0.84),
                softFill: Color(red: 0.33, green: 0.41, blue: 0.48)
            )
        }
    }

    static func sectionGlow(for category: ActionCategory, choice: AccentThemeChoice) -> Color {
        let palette = palette(for: choice)
        switch category {
        case .quickLaunch:
            return palette.accent
        case .workspace:
            return palette.accentSecondary
        case .system:
            return Color.white.opacity(0.86)
        case .preferences:
            return palette.softFill
        }
    }

    static func bannerGlow(for style: FeedbackBanner.Style, choice: AccentThemeChoice) -> Color {
        let palette = palette(for: choice)
        switch style {
        case .success:
            return palette.accentSecondary
        case .warning:
            return Color(red: 0.92, green: 0.79, blue: 0.58)
        case .error:
            return Color(red: 0.92, green: 0.60, blue: 0.62)
        }
    }
}
