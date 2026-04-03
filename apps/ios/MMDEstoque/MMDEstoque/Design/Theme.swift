import SwiftUI

// MARK: - Nothing Design System: Color Tokens

extension Color {

    // MARK: Backgrounds

    /// Pure black for OLED screens. Primary app background.
    static let ndBlack = Color(hex: 0x000000)

    /// Elevated surface (sheets, modals, navigation bars).
    static let ndSurface = Color(hex: 0x111111)

    /// Raised surface (cards, input fields, list rows).
    static let ndSurfaceRaised = Color(hex: 0x1A1A1A)

    // MARK: Borders

    /// Subtle divider between sections.
    static let ndBorder = Color(hex: 0x222222)

    /// Intentional, visible border (card edges, separators).
    static let ndBorderVisible = Color(hex: 0x333333)

    // MARK: Text

    /// Hero text, display numbers, maximum contrast.
    static let ndTextDisplay = Color.white

    /// Primary body text. Slightly softened white.
    static let ndTextPrimary = Color(hex: 0xE8E8E8)

    /// Labels, metadata, secondary information.
    static let ndTextSecondary = Color(hex: 0x999999)

    /// Disabled controls, decorative text.
    static let ndTextDisabled = Color(hex: 0x666666)

    // MARK: Accent & Status

    /// Brand accent (MMD red). Also used for MANUTENCAO and critical wear.
    static let ndAccent = Color(hex: 0xD71921)

    /// Success / OK / DISPONIVEL.
    static let ndSuccess = Color(hex: 0x4A9E5C)

    /// Warning / attention / EM_CAMPO.
    static let ndWarning = Color(hex: 0xD4A843)

    /// Interactive elements (links, tappable text).
    static let ndInteractive = Color(hex: 0x5B9BF6)

    // MARK: Hex Initializer

    /// Create a Color from a hex integer value.
    ///
    ///     Color(hex: 0xD71921)
    ///     Color(hex: 0x111111, opacity: 0.8)
    ///
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - Status Color Mapping

extension StatusSerial {

    /// The Nothing Design System color for this status.
    /// Color is applied to TEXT, never to backgrounds.
    var color: Color {
        switch self {
        case .disponivel:  return .ndSuccess
        case .packed:      return .ndTextDisplay
        case .emCampo:     return .ndWarning
        case .retornando:  return .ndInteractive
        case .manutencao:  return .ndAccent
        case .emprestado:  return .ndTextSecondary
        case .vendido:     return .ndTextDisabled
        case .baixa:       return .ndTextDisabled
        }
    }
}

// MARK: - Category Color Mapping

extension Categoria {

    /// Accent color used in category badges and indicators.
    var color: Color {
        switch self {
        case .iluminacao:  return .yellow
        case .audio:       return .blue
        case .cabo:        return .ndTextSecondary
        case .energia:     return .orange
        case .estrutura:   return .purple
        case .efeito:      return .pink
        case .video:       return .ndAccent
        case .acessorio:   return .ndSuccess
        }
    }
}

// MARK: - Wear/Desgaste Color Mapping

extension Int {

    /// Returns the Nothing Design System color for a wear level (1-5).
    ///
    /// - 5 (Excelente), 4 (Bom): success green
    /// - 3 (Regular): neutral white
    /// - 2 (Desgastado): warning yellow
    /// - 1 (Critico): accent red
    ///
    /// Values outside 1-5 return disabled gray.
    var wearColor: Color {
        switch self {
        case 5, 4:  return .ndSuccess
        case 3:     return .ndTextDisplay
        case 2:     return .ndWarning
        case 1:     return .ndAccent
        default:    return .ndTextDisabled
        }
    }
}
