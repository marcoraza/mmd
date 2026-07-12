import SwiftUI

// MARK: - GlassSurface
//
// A superficie fundamental do Liquid: vidro translucido sobre o caustic.
//
// Camadas, de tras para frente:
//   1. Material (backdrop blur que amostra o caustic atras, barato em bateria).
//   2. Tint branco translucido (o "leite" do vidro).
//   3. Borda base.
//   4. Highlight inset: aresta iluminada no topo/esquerda que finge espessura.
//   5. Sombra de projecao.
//
// `strong` escurece o scrim e reforca a borda, para telas de trabalho onde o
// dado precisa de contraste alto (regua: legibilidade primeiro). O scrim e a
// camada que garante o piso de contraste do texto mesmo quando um orb caustic
// brilhante passa atras do vidro.

struct GlassBackground: View {

    var cornerRadius: CGFloat = Liquid.Radius.lg
    var strong: Bool = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        shape
            .fill(strong ? Liquid.bg2 : Liquid.bg1)
            .overlay(shape.fill(strong ? Liquid.glassBgStrong : Liquid.glassBg))
            .overlay(
                shape.strokeBorder(
                    strong ? Liquid.glassBorderStrong : Liquid.glassBorder,
                    lineWidth: 1
                )
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Liquid.glassHighlight,
                            .clear,
                            .white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .compositingGroup()
            .liquidGlassShadow()
    }
}

// MARK: - GlassCard

/// Container de vidro com padding. Embrulha qualquer conteudo.
struct GlassCard<Content: View>: View {

    var cornerRadius: CGFloat = Liquid.Radius.lg
    var strong: Bool = false
    var padding: CGFloat = Liquid.Space.xxl
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(GlassBackground(cornerRadius: cornerRadius, strong: strong))
    }
}

// MARK: - PanelBackground
//
// Superficie de painel: preenchimento solido opaco + realce de luz no topo,
// sem backdrop blur. Antes usava .ultraThinMaterial, que em device custa
// caro (o blur re-amostra o fundo a cada frame, e mais ainda quando o painel
// se move numa transicao). O vidro le como vidro pela combinacao de tom
// (bg1/bg2/bgInset), aresta iluminada no topo e hairline, nao pelo blur: a
// luz de palco entra pelos vaos entre os paineis, nao atraves deles.

enum LiquidPanelTone {
    case base       // card padrao (bg1)
    case elevated   // painel destacado (bg2)
    case inset      // card acoplado que desliza por baixo (bgInset)

    var fill: Color {
        switch self {
        case .base:     return Liquid.bg1
        case .elevated: return Liquid.bg2
        case .inset:    return Liquid.bgInset
        }
    }
}

struct PanelBackground: View {

    var cornerRadius: CGFloat = Liquid.Radius.lg
    var tone: LiquidPanelTone = .base

    init(cornerRadius: CGFloat = Liquid.Radius.lg, tone: LiquidPanelTone = .base) {
        self.cornerRadius = cornerRadius
        self.tone = tone
    }

    init(cornerRadius: CGFloat = Liquid.Radius.lg, elevated: Bool) {
        self.cornerRadius = cornerRadius
        self.tone = elevated ? .elevated : .base
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        shape
            .fill(tone.fill)
            // Realce de luz no topo: finge o vidro pegando a luz-chave, sem
            // custo de blur (um gradiente linear estatico).
            .overlay(
                shape.fill(
                    LinearGradient(
                        colors: [.white.opacity(0.05), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Liquid.hairlineStrong, Liquid.hairline],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: .black.opacity(0.20), radius: 16, x: 0, y: 8)
    }
}

// MARK: - TechnicalGridCanvas
//
// Canvas do app: o palco. Duas fontes de luz fixas e direcionais no lugar
// dos orbs decorativos: uma luz-chave fria e alta (fresnel apagado lavando
// o topo da cena) e um contraluz vermelho de marca quase subliminar no pe.
// E a grade de pontos de blueprint por cima.
//
// Performance: o desenho e 100% estatico, entao `.drawingGroup()` rasteriza
// a cena inteira (gradientes + grade) numa unica textura Metal, renderizada
// uma vez e cacheada. Sem isso, o Canvas refazia o loop de pontos e os
// gradientes recompunham a cada frame, o que pesava ao animar a troca de aba.

struct TechnicalGridCanvas: View {

    var body: some View {
        ZStack {
            Liquid.bg0

            // Luz-chave: fria, alta, entrando pela esquerda. O raio passa da
            // diagonal da tela e o falloff tem parada intermediaria: a luz
            // morre FORA do quadro, nunca desenha borda dentro dele.
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(oklch: 0.78, 0.06, 230, opacity: 0.15), location: 0.0),
                    .init(color: Color(oklch: 0.78, 0.06, 230, opacity: 0.06), location: 0.42),
                    .init(color: .clear, location: 1.0),
                ]),
                center: UnitPoint(x: 0.22, y: -0.12),
                startRadius: 0,
                endRadius: 1100
            )

            // Contraluz de marca: MMD red no pe da cena, quase subliminar.
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(oklch: 0.55, 0.16, 25, opacity: 0.09), location: 0.0),
                    .init(color: Color(oklch: 0.55, 0.16, 25, opacity: 0.035), location: 0.45),
                    .init(color: .clear, location: 1.0),
                ]),
                center: UnitPoint(x: 1.05, y: 1.10),
                startRadius: 0,
                endRadius: 900
            )

            Canvas { context, size in
                let step: CGFloat = 22
                let dot: CGFloat = 1.0
                var y: CGFloat = step / 2
                while y < size.height {
                    var x: CGFloat = step / 2
                    while x < size.width {
                        let rect = CGRect(x: x, y: y, width: dot, height: dot)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.04)))
                        x += step
                    }
                    y += step
                }
            }
        }
        .drawingGroup()
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - PressableCardStyle
//
// Feedback tatil de card tocavel: encolhe levemente e clareia a superficie
// enquanto pressionado. Substitui o .plain nos cards de navegacao, que hoje
// nao dao resposta nenhuma ao toque.

struct PressableCardStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.05 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Liquid.Motion.fast, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableCardStyle {
    static var pressableCard: PressableCardStyle { PressableCardStyle() }
}

// MARK: - View Extension

extension View {

    /// Aplica a superficie de vidro como fundo do conteudo atual.
    func glassSurface(
        cornerRadius: CGFloat = Liquid.Radius.lg,
        strong: Bool = false
    ) -> some View {
        self.background(
            GlassBackground(cornerRadius: cornerRadius, strong: strong)
        )
    }

    /// Aplica painel de vidro com tint como fundo.
    func panelSurface(
        cornerRadius: CGFloat = Liquid.Radius.lg,
        elevated: Bool = false
    ) -> some View {
        self.background(
            PanelBackground(cornerRadius: cornerRadius, elevated: elevated)
        )
    }

    /// Variante por tom explicito (base, elevated, inset).
    func panelSurface(
        cornerRadius: CGFloat = Liquid.Radius.lg,
        tone: LiquidPanelTone
    ) -> some View {
        self.background(
            PanelBackground(cornerRadius: cornerRadius, tone: tone)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct GlassSurface_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            CausticBackground(intensity: .hero, includesGreenOrb: true)

            VStack(spacing: Liquid.Space.xxl) {
                GlassCard {
                    VStack(alignment: .leading, spacing: Liquid.Space.md) {
                        Text("PROJETO")
                            .liquidLabel()
                        Text("Festival de Inverno")
                            .liquidH2()
                        Text("18 itens prontos para despacho")
                            .liquidBody()
                    }
                }

                GlassCard(strong: true) {
                    VStack(alignment: .leading, spacing: Liquid.Space.md) {
                        Text("LEITOR")
                            .liquidLabel(Liquid.accentCyan)
                        Text("RFD40 conectado")
                            .liquidH3()
                    }
                }
            }
            .padding(Liquid.Space.xxl)
        }
        .preferredColorScheme(.dark)
    }
}
#endif
