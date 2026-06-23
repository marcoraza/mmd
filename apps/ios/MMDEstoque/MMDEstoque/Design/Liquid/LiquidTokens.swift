import SwiftUI
import Foundation

// MARK: - Liquid Glass 2030: Design Tokens
//
// Fonte da verdade: design_handoff_estoque_mmd/tokens/mmd-tokens.json
// Sistema dark-first, caustic-accented, glass-surfaced.
//
// As cores nascem em oklch (uniformidade perceptual). iOS nao tem oklch
// nativo, entao convertemos para Display P3 em tempo de execucao. P3 (e nao
// sRGB) porque os accents iridescentes (cyan, violet, green) caem fora do
// gamut sRGB; em sRGB eles seriam achatados por clamp, perdendo o brilho que
// e a assinatura do Liquid. iPhone e tela P3, entao a fidelidade chega ao olho.
//
// Namespace `Liquid` para zero colisao com os tokens Nothing (nd*), que
// coexistem durante a transicao.

enum Liquid {}

// MARK: - oklch -> Color (Display P3)

extension Color {

    /// Cria uma `Color` a partir de oklch, convertida para Display P3.
    ///
    /// - Parameters:
    ///   - l: Lightness, 0...1.
    ///   - c: Chroma, >= 0.
    ///   - h: Hue em graus, 0...360.
    init(oklch l: Double, _ c: Double, _ h: Double, opacity: Double = 1.0) {
        let (r, g, b) = Liquid.oklchToDisplayP3(l: l, c: c, h: h)
        self.init(.displayP3, red: r, green: g, blue: b, opacity: opacity)
    }
}

extension Liquid {

    /// oklch -> OKLab -> linear sRGB (Ottosson) -> XYZ(D65) -> linear P3 -> gamma.
    ///
    /// O caminho passa por linear sRGB porque as matrizes de Bjorn Ottosson sao
    /// definidas ali; cores fora do gamut sRGB aparecem como componentes
    /// negativos, que a conversao para P3 reaproveita em vez de descartar.
    static func oklchToDisplayP3(l L: Double, c C: Double, h H: Double) -> (Double, Double, Double) {
        let hr = H * .pi / 180.0
        let a = C * cos(hr)
        let b = C * sin(hr)

        // OKLab -> LMS^3 -> linear sRGB
        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b
        let lc = l_ * l_ * l_
        let mc = m_ * m_ * m_
        let sc = s_ * s_ * s_

        let rLin =  4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc
        let gLin = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc
        let bLin = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc

        // linear sRGB -> XYZ (D65)
        let x = 0.4124564 * rLin + 0.3575761 * gLin + 0.1804375 * bLin
        let y = 0.2126729 * rLin + 0.7151522 * gLin + 0.0721750 * bLin
        let z = 0.0193339 * rLin + 0.1191920 * gLin + 0.9503041 * bLin

        // XYZ -> linear Display P3
        let rP =  2.4934969 * x - 0.9313836 * y - 0.4027108 * z
        let gP = -0.8294890 * x + 1.7626641 * y + 0.0236247 * z
        let bP =  0.0358458 * x - 0.0761724 * y + 0.9568845 * z

        return (encodeGamma(rP), encodeGamma(gP), encodeGamma(bP))
    }

    /// Transferencia gamma sRGB (compartilhada pelo Display P3), com clamp em [0,1].
    private static func encodeGamma(_ v: Double) -> Double {
        let x = min(max(v, 0.0), 1.0)
        return x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1.0 / 2.4) - 0.055
    }

    /// Helper sRGB direto, para os hex literais dos gradientes de ring.
    fileprivate static func srgb(_ hex: UInt) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

// MARK: - Color Palette

extension Liquid {

    // Backgrounds: deep cool neutrals.
    static let bg0 = Color(oklch: 0.12, 0.015, 250)   // app background, deepest
    static let bg1 = Color(oklch: 0.16, 0.018, 250)   // secondary surface
    static let bg2 = Color(oklch: 0.20, 0.020, 250)   // raised panels

    // Foregrounds.
    static let fg0 = Color(oklch: 0.98, 0.005, 250)   // hi-contrast / primary
    static let fg1 = Color(oklch: 0.85, 0.008, 250)   // body
    static let fg2 = Color(oklch: 0.65, 0.010, 250)   // secondary / labels
    static let fg3 = Color(oklch: 0.48, 0.012, 250)   // tertiary / disabled

    // Accents: cool cyan e iridescente.
    static let accentCyan   = Color(oklch: 0.75, 0.14, 210)   // primary action, focus
    static let accentViolet = Color(oklch: 0.70, 0.17, 295)   // iridescent, hero moments
    static let accentAmber  = Color(oklch: 0.80, 0.15, 75)    // warning, partial
    static let accentGreen  = Color(oklch: 0.80, 0.17, 150)   // success, ready
    static let accentRed    = Color(oklch: 0.70, 0.18, 25)    // error, missing, critical

    // Glass tints: translucent whites.
    static let glassBg           = Color.white.opacity(0.05)
    static let glassBgStrong     = Color.white.opacity(0.09)
    static let glassBorder       = Color.white.opacity(0.10)
    static let glassBorderStrong = Color.white.opacity(0.18)
    static let glassHighlight    = Color.white.opacity(0.18)   // inset top/left fake thickness
}

// MARK: - Radii

extension Liquid {
    enum Radius {
        static let sm: CGFloat = 10   // chips, small buttons
        static let md: CGFloat = 16   // cards, inputs
        static let lg: CGFloat = 24   // panels, sheets
        static let xl: CGFloat = 32   // hero surfaces
    }
}

// MARK: - Blur

extension Liquid {
    enum Blur {
        static let sm: CGFloat = 12
        static let md: CGFloat = 24   // default glass blur
        static let lg: CGFloat = 40   // floating overlays
    }
}

// MARK: - Spacing
//
// Escala base 4px do handoff. Nomes semanticos para uso em SwiftUI.

extension Liquid {
    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let section: CGFloat = 32
        static let xWide: CGFloat = 48
        static let vast: CGFloat = 64
        static let hero: CGFloat = 80
    }
}

// MARK: - Motion
//
// Curva cubic-bezier(0.4, 0, 0.2, 1) do handoff, por duracao.

extension Liquid {
    enum Motion {
        static let instant   = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.08)
        static let fast      = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.18)
        static let `default` = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.24)
        static let slow      = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.42)   // hero transitions
    }
}

// MARK: - Readiness Ring Gradients
//
// Valor = % pronto. Hex sRGB diretos do handoff (sao paradas de gradiente,
// nao tokens de UI), do estado mais critico ao pronto.

extension Liquid {
    enum Ring {
        /// 0% a alguns: vermelho para ambar.
        static let missing: [Color] = [Liquid.srgb(0xFF6B6B), Liquid.srgb(0xFFB75C)]
        /// parcial: ambar para ciano.
        static let partial: [Color] = [Liquid.srgb(0xFFB75C), Liquid.srgb(0x7CC4FF)]
        /// pronto: verde -> ciano -> verde. Fecha o circulo sem costura visivel
        /// em 100%, que e justamente quando o estado pronto aparece (hero).
        static let ready:   [Color] = [Liquid.srgb(0x6DD18E), Liquid.srgb(0x7CC4FF), Liquid.srgb(0x6DD18E)]

        static let sizeSm: CGFloat = 48
        static let sizeMd: CGFloat = 72
        static let sizeLg: CGFloat = 120
        static let sizeXl: CGFloat = 200

        static let strokeSm: CGFloat = 4
        static let strokeMd: CGFloat = 6
        static let strokeLg: CGFloat = 10
        static let strokeXl: CGFloat = 14
    }
}

// MARK: - Shadows & Glow

extension View {

    /// Sombra padrao de superficie de vidro (dark mode). Duas camadas:
    /// contato curto e projecao longa e suave.
    func liquidGlassShadow() -> some View {
        self
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
            .shadow(color: .black.opacity(0.35), radius: 30, x: 0, y: 20)
    }

    /// Sombra de overlay flutuante (modais, sheets).
    func liquidElevatedShadow() -> some View {
        self
            .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 4)
            .shadow(color: .black.opacity(0.45), radius: 40, x: 0, y: 30)
    }

    /// Halo de glow colorido, para momentos hero.
    func liquidGlow(_ color: Color, radius: CGFloat = 24, opacity: Double = 0.4) -> some View {
        self.shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 0)
    }
}
