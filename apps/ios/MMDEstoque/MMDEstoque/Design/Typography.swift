import SwiftUI

// MARK: - Nothing Design System: Typography

extension Font {

    // MARK: Font Families

    /// Space Grotesk: body text, titles, item names.
    ///
    /// Falls back to `.system(size:design:.default)` if the font isn't loaded.
    static func spaceGrotesk(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold:      name = "SpaceGrotesk-Bold"
        case .semibold:  name = "SpaceGrotesk-SemiBold"
        case .medium:    name = "SpaceGrotesk-Medium"
        default:         name = "SpaceGrotesk-Regular"
        }
        return .custom(name, size: size, relativeTo: .body)
    }

    /// Space Mono: labels ALL CAPS, codes MMD-XXX-NNNN, counters, badges, numbers.
    ///
    /// Falls back to `.system(size:design:.monospaced)` if the font isn't loaded.
    static func spaceMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name = weight == .bold ? "SpaceMono-Bold" : "SpaceMono-Regular"
        return .custom(name, size: size, relativeTo: .caption)
    }

    /// Doto: hero numbers (scan count, progress, KPIs). 36px and above.
    ///
    /// Falls back to `.system(size:design:.rounded)` if the font isn't loaded.
    static func doto(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let name = weight == .bold ? "Doto-Bold" : "Doto-Regular"
        return .custom(name, size: size, relativeTo: .largeTitle)
    }

    // MARK: Semantic Scale

    /// 72px Doto. Hero numbers on dashboard (scan count, total value).
    static let displayXL  = Font.doto(72)

    /// 48px Doto. Secondary KPIs.
    static let displayLG  = Font.doto(48)

    /// 36px Doto. Page titles with numeric emphasis.
    static let displayMD  = Font.doto(36)

    /// 24px Space Grotesk semibold. Section titles.
    static let ndHeading  = Font.spaceGrotesk(24, weight: .semibold)

    /// 18px Space Grotesk medium. Subtitles.
    static let ndSubheading = Font.spaceGrotesk(18, weight: .medium)

    /// 16px Space Grotesk regular. Body text, item names.
    static let ndBody     = Font.spaceGrotesk(16)

    /// 14px Space Grotesk regular. Secondary text.
    static let ndBodySm   = Font.spaceGrotesk(14)

    /// 12px Space Mono. Timestamps, metadata.
    static let ndCaption  = Font.spaceMono(12)

    /// 11px Space Mono. ALL CAPS labels (use with `.ndLabel()` modifier).
    static let ndLabel    = Font.spaceMono(11)

    /// 9px Space Mono. Smallest label size (badges, micro-labels).
    static let ndLabelSm  = Font.spaceMono(9)
}

// MARK: - Label Style Modifiers

extension View {

    /// Applies the Nothing label style: ALL CAPS, letter-spacing 0.08em,
    /// 11px Space Mono, secondary text color.
    ///
    /// Use for section headers, metadata labels, and badge text.
    func ndLabel() -> some View {
        self
            .font(.ndLabel)
            .textCase(.uppercase)
            .tracking(11 * 0.08) // 0.08em relative to font size
            .foregroundStyle(Color.ndTextSecondary)
    }

    /// Same as `.ndLabel()` but with a custom color.
    ///
    /// Use for status-colored labels, category badges, etc.
    func ndLabelAccent(_ color: Color) -> some View {
        self
            .font(.ndLabel)
            .textCase(.uppercase)
            .tracking(11 * 0.08)
            .foregroundStyle(color)
    }

    /// Small label variant (9px). Same rules: ALL CAPS, letter-spacing 0.08em.
    func ndLabelSmall() -> some View {
        self
            .font(.ndLabelSm)
            .textCase(.uppercase)
            .tracking(9 * 0.08)
            .foregroundStyle(Color.ndTextSecondary)
    }

    /// Small label variant with custom color.
    func ndLabelSmallAccent(_ color: Color) -> some View {
        self
            .font(.ndLabelSm)
            .textCase(.uppercase)
            .tracking(9 * 0.08)
            .foregroundStyle(color)
    }
}

// MARK: - Spacing Constants

/// Nothing Design System spacing scale. Base unit: 8px.
enum NDSpacing {
    /// 4px. Tight gap between label and its value.
    static let tight: CGFloat = 4

    /// 8px. Base unit. Inline padding, small gaps.
    static let base: CGFloat = 8

    /// 12px. Compact list item spacing.
    static let compact: CGFloat = 12

    /// 16px. Standard list item spacing, card padding.
    static let medium: CGFloat = 16

    /// 24px. Between related sections.
    static let section: CGFloat = 24

    /// 32px. Between distinct sections.
    static let wide: CGFloat = 32

    /// 48px. Large section breaks.
    static let xWide: CGFloat = 48

    /// 64px. Space around hero elements.
    static let vast: CGFloat = 64

    /// 96px. Maximum breathing room (hero top/bottom).
    static let hero: CGFloat = 96
}
