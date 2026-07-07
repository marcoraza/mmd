import SwiftUI

// MARK: - Liquid Color Mappings
//
// Mapeamentos de cor por dominio na paleta Liquid (oklch). Nome `liquidColor`
// para coexistir com as extensoes `.color` do Nothing sem colisao. Removidas
// junto com o Theme antigo na Wave 1 (limpeza Codex).

extension StatusSerial {
    var liquidColor: Color {
        switch self {
        case .disponivel:  return Liquid.accentGreen
        case .packed:      return Liquid.accentCyan
        case .emCampo:     return Liquid.accentAmber
        case .retornando:  return Liquid.accentViolet
        case .manutencao:  return Liquid.accentRed
        case .emprestado:  return Liquid.fg1
        case .vendido:     return Liquid.fg2
        case .baixa:       return Liquid.fg2
        }
    }
}

extension StatusProjeto {
    var liquidColor: Color {
        switch self {
        case .planejamento: return Liquid.fg2
        case .confirmado:   return Liquid.accentGreen
        case .emCampo:      return Liquid.accentAmber
        case .finalizado:   return Liquid.fg3
        case .cancelado:    return Liquid.accentRed
        }
    }
}

extension TipoMovimentacao {
    var liquidColor: Color {
        switch self {
        case .saida:         return Liquid.accentAmber
        case .retorno:       return Liquid.accentGreen
        case .manutencao:    return Liquid.accentRed
        case .transferencia: return Liquid.accentCyan
        case .dano:          return Liquid.accentRed
        }
    }
}

extension Categoria {
    /// Cores derivadas em oklch, mesma familia perceptual (L/C proximos),
    /// hues distintos, para os badges de categoria nao brigarem entre si.
    var liquidColor: Color {
        switch self {
        case .iluminacao: return Color(oklch: 0.80, 0.15, 75)   // ambar
        case .audio:      return Color(oklch: 0.75, 0.14, 210)  // ciano
        case .cabo:       return Liquid.fg2                      // neutro
        case .energia:    return Color(oklch: 0.78, 0.15, 50)   // laranja
        case .estrutura:  return Color(oklch: 0.70, 0.17, 295)  // violeta
        case .efeito:     return Color(oklch: 0.72, 0.17, 350)  // magenta
        case .video:      return Color(oklch: 0.70, 0.15, 250)  // azul
        case .acessorio:  return Color(oklch: 0.80, 0.17, 150)  // verde
        }
    }
}

extension Int {
    /// Cor de desgaste (1-5) na paleta Liquid.
    /// 5,4 verde; 3 neutro; 2 ambar; 1 vermelho.
    var liquidWearColor: Color {
        switch self {
        case 5, 4:  return Liquid.accentGreen
        case 3:     return Liquid.fg1
        case 2:     return Liquid.accentAmber
        case 1:     return Liquid.accentRed
        default:    return Liquid.fg3
        }
    }
}

// MARK: - LiquidSectionHeader
//
// Header de secao na voz de micro-label do sistema: mono espacado, mesma
// tipografia dos headers internos de card ("PROXIMO EVENTO"). Trailing
// opcional em mono pra contagem ou dado tecnico.

struct LiquidSectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: Liquid.Space.sm) {
            Text(title.uppercased())
                .font(.liquidMono(10, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Liquid.fg2)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.liquidMono(11, weight: .medium))
                    .foregroundStyle(Liquid.fg2)
            }
        }
    }
}

// MARK: - LiquidSkeleton
//
// Placeholder de carregamento com a anatomia dos cards reais: barras no
// lugar de titulo e metadados, pulso lento de opacidade. Mantem a estrutura
// percebida da tela enquanto o dado chega (spinner central some com o
// layout). Respeita reduce motion.

struct LiquidSkeletonCard: View {

    var minHeight: CGFloat = 0

    @State private var dimmed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.sm) {
            bar(width: 180, height: 14)
            bar(width: 110, height: 10)
            bar(width: 150, height: 10)
        }
        .padding(Liquid.Space.lg)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .panelSurface(cornerRadius: Liquid.Radius.md)
        .opacity(dimmed ? 0.55 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                dimmed = true
            }
        }
        .accessibilityHidden(true)
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(Liquid.bg2)
            .frame(width: width, height: height)
    }
}

/// Lista de skeletons pronta pra estados de loading de tela.
struct LiquidSkeletonList: View {

    var rows: Int = 4
    var rowMinHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: Liquid.Space.sm) {
            ForEach(0..<rows, id: \.self) { _ in
                LiquidSkeletonCard(minHeight: rowMinHeight)
            }
        }
        .accessibilityLabel("Carregando")
    }
}

// MARK: - LiquidStatusBadge
//
// Pill de vidro: texto na cor do estado, fundo tint suave, borda na mesma cor.

struct LiquidStatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.liquidMono(10, weight: .medium))
            .textCase(.uppercase)
            .tracking(1.0)
            .foregroundStyle(color)
            .padding(.horizontal, Liquid.Space.md)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Liquid.bg0.opacity(0.6))
                    .overlay(Capsule().fill(color.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1))
            )
    }

    init(text: String, color: Color) {
        self.text = text
        self.color = color
    }

    init(status: StatusSerial) {
        self.text = status.displayName
        self.color = status.liquidColor
    }

    init(projeto: StatusProjeto) {
        self.text = projeto.displayName
        self.color = projeto.liquidColor
    }
}

// MARK: - LiquidCategoryBadge

struct LiquidCategoryBadge: View {
    let categoria: Categoria

    var body: some View {
        LiquidStatusBadge(text: categoria.displayName, color: categoria.liquidColor)
    }
}

// MARK: - LiquidWearBar
//
// Cinco segmentos arredondados (Liquid), preenchidos ate o nivel.

struct LiquidWearBar: View {
    let level: Int
    var height: CGFloat = 6

    private let total = 5

    private var clamped: Int { min(max(level, 0), total) }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...total, id: \.self) { index in
                Capsule()
                    .fill(index <= clamped ? clamped.liquidWearColor : Liquid.glassBorderStrong)
                    .frame(height: height)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Desgaste \(clamped) de \(total)")
    }
}

/// LiquidWearBar com o numero ao lado.
struct LiquidWearBarLabeled: View {
    let level: Int

    var body: some View {
        HStack(spacing: Liquid.Space.md) {
            LiquidWearBar(level: level)
            Text("\(level)/5")
                .font(.liquidMono(12, weight: .medium))
                .foregroundStyle(level.liquidWearColor)
        }
    }
}

// MARK: - LiquidProgressBar
//
// Barra segmentada de contagem variavel. Cai para barra continua quando
// passa de `maxVisibleSegments`.

struct LiquidProgressBar: View {
    let total: Int
    let filled: Int
    var color: Color = Liquid.accentGreen
    var trackColor: Color = Liquid.glassBorder
    var height: CGFloat = 6
    var maxVisibleSegments: Int = 20

    var body: some View {
        if total <= 0 {
            Capsule().fill(trackColor).frame(height: height)
        } else if total <= maxVisibleSegments {
            HStack(spacing: 3) {
                ForEach(0..<total, id: \.self) { index in
                    Capsule()
                        .fill(index < filled ? color : trackColor)
                        .frame(height: height)
                }
            }
        } else {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(trackColor)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(filled) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: height)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LiquidComponents_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            CausticBackground(intensity: .work)

            ScrollView {
                VStack(alignment: .leading, spacing: Liquid.Space.xxl) {
                    Text("STATUS")
                        .liquidLabel()
                    FlowRow {
                        ForEach(StatusSerial.allCases) { LiquidStatusBadge(status: $0) }
                    }

                    Text("CATEGORIAS")
                        .liquidLabel()
                    FlowRow {
                        ForEach(Categoria.allCases) { LiquidCategoryBadge(categoria: $0) }
                    }

                    Text("DESGASTE")
                        .liquidLabel()
                    VStack(spacing: Liquid.Space.md) {
                        ForEach(1...5, id: \.self) { LiquidWearBarLabeled(level: $0) }
                    }

                    Text("PROGRESSO")
                        .liquidLabel()
                    LiquidProgressBar(total: 12, filled: 8)
                    LiquidProgressBar(total: 12, filled: 12)
                    LiquidProgressBar(total: 30, filled: 18, color: Liquid.accentAmber)
                }
                .padding(Liquid.Space.section)
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// Layout auxiliar so para o preview: quebra os badges em linhas.
private struct FlowRow<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: Liquid.Space.sm) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
