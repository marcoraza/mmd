import SwiftUI

// MARK: - CausticBackground
//
// O fundo iridescente do Liquid: orbs ciano e violeta desfocados sob o vidro,
// com blend `.screen` para o brilho somar em vez de cobrir. Um terceiro orb
// verde e opcional.
//
// A intensidade e a regua visual da decisao 1: `.hero` para o momento
// cinematografico do scan, `.work` para telas de trabalho onde o dado manda e
// o caustic so respira no fundo.

struct CausticBackground: View {

    enum Intensity {
        case hero    // momento uau: orbs vivos, leve deriva
        case work    // telas de trabalho: contido, estatico
        case ambient // quase imperceptivel

        var orbOpacity: Double {
            switch self {
            case .hero:    return 0.55
            case .work:    return 0.20
            case .ambient: return 0.14
            }
        }

        var animates: Bool { self == .hero }
    }

    var intensity: Intensity = .hero
    var includesGreenOrb: Bool = false

    @State private var drift = false

    /// Respeita "Reduzir Movimento" das Acessibilidades.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxDim = max(w, h)
            let diameter = maxDim * 0.92
            let shift: CGFloat = intensity.animates ? 18 : 0

            ZStack {
                Liquid.bg0

                orb(color: Liquid.accentCyan, diameter: diameter)
                    .position(x: w * 0.14 + (drift ? shift : -shift),
                              y: h * 0.06 + (drift ? -shift : shift))

                orb(color: Liquid.accentViolet, diameter: diameter * 1.02)
                    .position(x: w * 0.90 + (drift ? -shift : shift),
                              y: h * 0.94 + (drift ? shift : -shift))

                if includesGreenOrb {
                    orb(color: Liquid.accentGreen, diameter: diameter * 0.8, opacityScale: 0.6)
                        .position(x: w * 0.55, y: h * 0.40)
                }
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .ignoresSafeArea()
        .onAppear {
            guard intensity.animates, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    // MARK: - Orb

    private func orb(color: Color, diameter: CGFloat, opacityScale: Double = 1.0) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(intensity.orbOpacity * opacityScale),
                        color.opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.5
                )
            )
            .frame(width: diameter, height: diameter)
            .blur(radius: 60)
            .blendMode(.screen)
            .allowsHitTesting(false)
    }
}

// MARK: - View Extension

extension View {

    /// Aplica o fundo caustic atras do conteudo.
    func liquidCausticBackground(
        _ intensity: CausticBackground.Intensity = .work,
        greenOrb: Bool = false
    ) -> some View {
        self.background(
            CausticBackground(intensity: intensity, includesGreenOrb: greenOrb)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct CausticBackground_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CausticBackground(intensity: .hero, includesGreenOrb: true)
                .previewDisplayName("Hero")

            CausticBackground(intensity: .work)
                .previewDisplayName("Work")
        }
        .preferredColorScheme(.dark)
    }
}
#endif
