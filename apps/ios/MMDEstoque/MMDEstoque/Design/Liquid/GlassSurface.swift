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

    /// Piso de contraste: escurece o vidro sob o texto. Mais forte em telas de
    /// trabalho (strong), mais leve no padrao, onde o caustic respira mais.
    private var scrimOpacity: Double { strong ? 0.48 : 0.30 }

    var body: some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay(shape.fill(Liquid.bg0.opacity(scrimOpacity)))
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
// Superficie solida em camadas, para telas com fundo neutro (sem caustic).
// O vidro translucido sobre fundo chapado vira cinza lamacento; o painel
// solido devolve profundidade por contraste de valor: bg1 sobre bg0, bg2 nos
// chips. Hairline com gradiente vertical finge aresta iluminada sem glow.

struct PanelBackground: View {

    var cornerRadius: CGFloat = Liquid.Radius.lg
    var elevated: Bool = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        shape
            .fill(elevated ? Liquid.bg2 : Liquid.bg1)
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

    /// Aplica painel solido como fundo. Para telas de fundo neutro.
    func panelSurface(
        cornerRadius: CGFloat = Liquid.Radius.lg,
        elevated: Bool = false
    ) -> some View {
        self.background(
            PanelBackground(cornerRadius: cornerRadius, elevated: elevated)
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
