import SwiftUI

// MARK: - LiquidItemDetailView
//
// Detalhe da unidade fisica (serial). O coracao e o sistema de condicao:
// Estado + Desgaste + Depreciacao, com a formula visivel
// (valor_original x desgaste/5 x fator = valor_atual). Porte do mockup
// item-detail, adaptado pro mobile. Dados reais do SerialNumber + Equipment.

struct LiquidItemDetailView: View {

    let serial: SerialNumber

    private var item: Equipment? { serial.item }
    private var valorOriginal: Double { item?.valorMercadoUnitario ?? 0 }
    private var fator: Double { serial.estado.fatorDepreciacao }
    private var valorAtual: Double { serial.valorAtual ?? serial.calcularValorAtual(valorOriginal: valorOriginal) }
    private var pctRestante: Double {
        guard valorOriginal > 0 else { return 0 }
        return min(max(valorAtual / valorOriginal, 0), 1)
    }

    var body: some View {
        ZStack {
            CausticBackground(intensity: .work)

            ScrollView {
                VStack(spacing: Liquid.Space.lg) {
                    identityCard
                    conditionCard
                }
                .padding(Liquid.Space.lg)
                .padding(.bottom, Liquid.Space.vast)
            }
        }
        .navigationTitle("Unidade")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: Identidade

    private var identityCard: some View {
        GlassCard(strong: true) {
            VStack(alignment: .leading, spacing: Liquid.Space.lg) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Liquid.Space.xs) {
                        Text("Unidade física").liquidLabel(Liquid.accentCyan)
                        Text(item?.displayName ?? item?.nome ?? "Serial")
                            .liquidH2()
                        if let item {
                            Text([item.marca, item.modelo, item.categoria.displayName]
                                .compactMap { $0 }.joined(separator: ", "))
                                .liquidSmall()
                        }
                    }
                    Spacer()
                    LiquidStatusBadge(status: serial.status)
                }

                Rectangle().fill(Liquid.glassBorder).frame(height: 1)

                VStack(spacing: Liquid.Space.sm) {
                    kv("Código interno", serial.codigoInterno)
                    if let tag = serial.tagRfid { kv("Tag RFID", tag) }
                    if let fab = serial.serialFabrica { kv("Serial fábrica", fab) }
                    if let loc = serial.localizacao { kv("Localização", loc) }
                }
            }
        }
    }

    private func kv(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).liquidSmall().foregroundStyle(Liquid.fg2)
            Spacer()
            Text(value).liquidMonoData(12, color: Liquid.fg1).lineLimit(1).truncationMode(.middle)
        }
    }

    // MARK: Condicao

    private var conditionCard: some View {
        GlassCard(strong: true) {
            VStack(alignment: .leading, spacing: Liquid.Space.xl) {
                Text("Condição da unidade").liquidH3()

                wearRing

                estadoSegmented

                depreciacaoBlock

                formulaBlock
            }
        }
    }

    private var wearRing: some View {
        let color = serial.desgaste.liquidWearColor
        return HStack(spacing: Liquid.Space.xl) {
            ZStack {
                Circle().stroke(Liquid.glassBorderStrong, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(serial.desgaste) / 5)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(serial.desgaste)").font(.liquidMono(30, weight: .medium)).foregroundStyle(Liquid.fg0)
                    Text("de 5").liquidMonoData(10, color: Liquid.fg2)
                }
            }
            .frame(width: 104, height: 104)

            VStack(alignment: .leading, spacing: Liquid.Space.xs) {
                Text("Desgaste").liquidLabel()
                Text(desgasteLabel).font(.liquidSans(17, weight: .medium)).foregroundStyle(color)
                Text("Última avaliação no retorno").liquidSmall().foregroundStyle(Liquid.fg3)
            }
            Spacer()
        }
    }

    private var estadoSegmented: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.sm) {
            Text("Estado").liquidLabel()
            HStack(spacing: Liquid.Space.sm) {
                ForEach(Estado.allCases) { e in
                    let on = e == serial.estado
                    Text(estadoShort(e))
                        .font(.liquidMono(11, weight: .medium))
                        .foregroundStyle(on ? Liquid.bg0 : Liquid.fg2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Liquid.Space.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Liquid.Radius.sm, style: .continuous)
                                .fill(on ? Liquid.accentCyan : Liquid.glassBg)
                                .overlay(RoundedRectangle(cornerRadius: Liquid.Radius.sm, style: .continuous)
                                    .strokeBorder(on ? Color.clear : Liquid.glassBorder, lineWidth: 1))
                        )
                }
            }
            Text("fator \(String(format: "%.2f", fator))").liquidMonoData(10, color: Liquid.accentCyan)
        }
    }

    private var depreciacaoBlock: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.sm) {
            Text("Depreciação").liquidLabel()
            ZStack(alignment: .leading) {
                Capsule().fill(Liquid.glassBorderStrong).frame(height: 8)
                GeometryReader { geo in
                    Capsule()
                        .fill(LinearGradient(colors: [Liquid.accentGreen, Liquid.accentCyan],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * pctRestante, height: 8)
                }
                .frame(height: 8)
            }
            HStack {
                valueBlock("Valor original", money(valorOriginal), Liquid.fg1)
                Spacer()
                valueBlock("Valor atual", money(valorAtual), Liquid.fg0)
            }
        }
    }

    private func valueBlock(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).liquidLabel()
            Text(value).font(.liquidSans(18, weight: .medium)).foregroundStyle(color)
        }
    }

    private var formulaBlock: some View {
        let d = serial.desgaste
        return VStack(alignment: .leading, spacing: 4) {
            Text("valor_atual = \(money(valorOriginal)) × (\(d)/5) × \(String(format: "%.2f", fator))")
            Text("= \(money(valorOriginal)) × \(String(format: "%.2f", Double(d) / 5)) × \(String(format: "%.2f", fator))")
            (Text("= ").foregroundColor(Liquid.fg2)
                + Text(money(valorAtual)).foregroundColor(Liquid.accentCyan))
        }
        .font(.liquidMono(12))
        .foregroundStyle(Liquid.fg2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Liquid.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Liquid.Radius.sm, style: .continuous)
                .fill(Liquid.bg0.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: Liquid.Radius.sm, style: .continuous)
                    .strokeBorder(Liquid.glassBorder, lineWidth: 1))
        )
    }

    // MARK: Helpers

    private var desgasteLabel: String {
        switch serial.desgaste {
        case 5: return "Excelente"
        case 4: return "Bom estado"
        case 3: return "Regular"
        case 2: return "Desgastado"
        case 1: return "Crítico"
        default: return "Desconhecido"
        }
    }

    private func estadoShort(_ e: Estado) -> String {
        switch e {
        case .novo: return "NOVO"
        case .semiNovo: return "SEMI"
        case .usado: return "USADO"
        case .recondicionado: return "RECOND"
        }
    }

    private func money(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "R$ \(Int(v))"
    }
}
