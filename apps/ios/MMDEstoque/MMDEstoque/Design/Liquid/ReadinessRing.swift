import SwiftUI

// MARK: - ReadinessState
//
// Tres faixas de prontidao, cada uma com seu gradiente. O estado pode ser
// derivado do progresso ou forcado pelo chamador.

enum ReadinessState {
    case missing   // critico: maior parte faltando
    case partial   // a caminho
    case ready     // completo

    /// Deriva o estado a partir do progresso (0...1).
    static func from(progress: Double) -> ReadinessState {
        switch progress {
        case let p where p >= 1.0:  return .ready
        case let p where p >= 0.5:  return .partial
        default:                    return .missing
        }
    }

    var gradient: [Color] {
        switch self {
        case .missing: return Liquid.Ring.missing
        case .partial: return Liquid.Ring.partial
        case .ready:   return Liquid.Ring.ready
        }
    }

    var solid: Color {
        switch self {
        case .missing: return Liquid.accentRed
        case .partial: return Liquid.accentAmber
        case .ready:   return Liquid.accentGreen
        }
    }
}

// MARK: - ReadinessRing
//
// O ring de prontidao: trilha de vidro + arco de progresso com gradiente
// angular. Comeca no topo, cresce no sentido horario, ponta arredondada.
// Sem conteudo central: o chamador sobrepoe o que quiser via `.overlay`.

struct ReadinessRing: View {

    /// Fracao preenchida, 0...1.
    let progress: Double

    /// Estado explicito; quando nil, deriva do progresso.
    var state: ReadinessState? = nil

    var diameter: CGFloat = Liquid.Ring.sizeLg
    var stroke: CGFloat = Liquid.Ring.strokeLg

    /// Halo de glow na cor do estado. Liga no hero, desliga no trabalho.
    var glow: Bool = false

    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var resolvedState: ReadinessState {
        state ?? .from(progress: clamped)
    }

    private var clamped: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            // Trilha
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: stroke)

            // Arco de progresso
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: resolvedState.gradient),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: stroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .liquidGlow(
                    glow ? resolvedState.solid : .clear,
                    radius: glow ? stroke * 1.2 : 0,
                    opacity: glow ? 0.6 : 0
                )
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement()
        .accessibilityLabel("Prontidão")
        .accessibilityValue("\(Int(clamped * 100)) por cento")
        .onAppear { animate(to: clamped) }
        .onChange(of: progress) { _ in animate(to: clamped) }
    }

    private func animate(to value: Double) {
        if reduceMotion {
            animatedProgress = value
        } else {
            withAnimation(Liquid.Motion.slow) { animatedProgress = value }
        }
    }
}

// MARK: - ReadinessGauge
//
// Conveniencia: ring + percentual no centro (mono), com label opcional.

struct ReadinessGauge: View {

    let progress: Double
    var state: ReadinessState? = nil
    var diameter: CGFloat = Liquid.Ring.sizeLg
    var stroke: CGFloat = Liquid.Ring.strokeLg
    var glow: Bool = false
    var caption: String? = nil

    private var clamped: Double { min(max(progress, 0), 1) }

    private var resolvedState: ReadinessState {
        state ?? .from(progress: clamped)
    }

    var body: some View {
        ReadinessRing(
            progress: progress,
            state: state,
            diameter: diameter,
            stroke: stroke,
            glow: glow
        )
        .overlay {
            VStack(spacing: 2) {
                Text("\(Int(clamped * 100))")
                    .font(.liquidMono(diameter * 0.26, weight: .medium))
                    .foregroundStyle(Liquid.fg0)
                    .contentTransition(.numericText())

                if let caption {
                    Text(caption)
                        .liquidLabel(resolvedState.solid)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ReadinessRing_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            CausticBackground(intensity: .hero)

            VStack(spacing: Liquid.Space.section) {
                ReadinessGauge(
                    progress: 1.0,
                    diameter: Liquid.Ring.sizeXl,
                    stroke: Liquid.Ring.strokeXl,
                    glow: true,
                    caption: "Pronto"
                )

                HStack(spacing: Liquid.Space.section) {
                    ReadinessGauge(progress: 0.35, caption: "Faltando")
                    ReadinessGauge(progress: 0.72, caption: "Parcial")
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
#endif
