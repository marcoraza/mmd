import SwiftUI
import Foundation

// Conversor oklch -> Display P3. As cores do Event Pro nascem em oklch
// (uniformidade perceptual); P3 preserva os accents que caem fora do sRGB.

// MARK: - oklch -> Color (Display P3)

extension Color {

    /// Cria uma `Color` a partir de oklch, convertida para Display P3.
    ///
    /// - Parameters:
    ///   - l: Lightness, 0...1.
    ///   - c: Chroma, >= 0.
    ///   - h: Hue em graus, 0...360.
    init(oklch l: Double, _ c: Double, _ h: Double, opacity: Double = 1.0) {
        let (r, g, b) = OKLCH.oklchToDisplayP3(l: l, c: c, h: h)
        self.init(.displayP3, red: r, green: g, blue: b, opacity: opacity)
    }
}

enum OKLCH {

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
