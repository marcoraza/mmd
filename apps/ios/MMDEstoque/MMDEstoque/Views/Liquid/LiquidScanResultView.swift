import SwiftUI

// MARK: - LiquidScanResultView
//
// Reskin Liquid do ScanResultView. Resultado do scan de identificacao:
// itens resolvidos em cards de vidro (toque expande detalhe) e tags sem
// match numa secao a parte, com atalho mental pra Etiquetar (a tag virgem
// precisa de vinculo). Tela de trabalho: caustic .work, cards strong sob
// dado, alto contraste.

struct LiquidScanResultView: View {

    let resolved: [ResolvedItem]
    let unresolved: [String]

    @EnvironmentObject private var router: LiquidRouter
    @State private var expandedItemId: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Liquid.Space.section) {
                heroSummary
                resolvedSection
                unresolvedSection
            }
            .padding(Liquid.Space.xxl)
            .padding(.bottom, Liquid.Space.vast)
        }
        .background(CausticBackground(intensity: .work).ignoresSafeArea())
        .navigationTitle("Resultado")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Hero Summary

    private var heroSummary: some View {
        HStack(spacing: Liquid.Space.section) {
            heroCount("\(resolved.count)", label: "Resolvidos", color: Liquid.accentGreen)

            if !unresolved.isEmpty {
                heroCount("\(unresolved.count)", label: "Sem match", color: Liquid.accentAmber)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, Liquid.Space.sm)
    }

    private func heroCount(_ value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Liquid.Space.xs) {
            Text(value)
                .font(.liquidHero(52))
                .foregroundStyle(Liquid.fg0)
                .contentTransition(.numericText())

            Text(label)
                .liquidLabel(color)
        }
    }

    // MARK: - Resolved Section

    @ViewBuilder
    private var resolvedSection: some View {
        if !resolved.isEmpty {
            VStack(alignment: .leading, spacing: Liquid.Space.md) {
                Text("Itens identificados")
                    .liquidLabel()

                VStack(spacing: Liquid.Space.md) {
                    ForEach(resolved) { item in
                        resolvedCard(item)
                    }
                }
            }
        }
    }

    private func resolvedCard(_ item: ResolvedItem) -> some View {
        let isExpanded = expandedItemId == item.id

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : Liquid.Motion.fast) {
                    expandedItemId = isExpanded ? nil : item.id
                }
            } label: {
                cardHeader(item, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedDetails(item)
                    .padding(.top, Liquid.Space.lg)
            }
        }
        .padding(Liquid.Space.lg)
        .glassSurface(cornerRadius: Liquid.Radius.md, strong: true)
    }

    private func cardHeader(_ item: ResolvedItem, isExpanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: Liquid.Space.sm) {
            HStack(alignment: .top, spacing: Liquid.Space.md) {
                VStack(alignment: .leading, spacing: Liquid.Space.xs) {
                    Text(item.displayName)
                        .liquidH3()
                        .foregroundStyle(Liquid.fg0)
                        .lineLimit(1)

                    Text(item.codigoInterno)
                        .liquidMonoData(12, color: Liquid.fg2)
                }

                Spacer(minLength: Liquid.Space.sm)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Liquid.fg3)
                    .padding(.top, 3)
            }

            HStack(spacing: Liquid.Space.sm) {
                LiquidCategoryBadge(categoria: item.categoria)
                LiquidStatusBadge(status: item.serialNumber.status)

                Spacer(minLength: 0)

                LiquidWearBar(level: item.serialNumber.desgaste)
                    .frame(width: 64)
            }
        }
    }

    // MARK: - Expanded Details

    private func expandedDetails(_ item: ResolvedItem) -> some View {
        let serial = item.serialNumber

        return VStack(spacing: Liquid.Space.md) {
            Divider().overlay(Liquid.glassBorder)

            detailRow("Estado") {
                Text(serial.estado.displayName)
                    .liquidMonoData(13, color: Liquid.fg1)
            }

            detailRow("Desgaste") {
                HStack(spacing: Liquid.Space.sm) {
                    Text(serial.desgasteLabel)
                        .liquidMonoData(13, color: serial.desgaste.liquidWearColor)
                    Text("\(serial.desgaste)/5")
                        .liquidMonoData(13, color: serial.desgaste.liquidWearColor)
                }
            }

            if let valor = item.valorFormatado {
                detailRow("Valor atual") {
                    Text(valor)
                        .liquidMonoData(13, color: Liquid.fg1)
                }
            }

            if let localizacao = serial.localizacao {
                detailRow("Localização") {
                    Text(localizacao)
                        .liquidMonoData(13, color: Liquid.fg1)
                        .multilineTextAlignment(.trailing)
                }
            }

            if let marca = item.equipment.marca, let modelo = item.equipment.modelo {
                detailRow("Equipamento") {
                    Text("\(marca) \(modelo)")
                        .liquidMonoData(13, color: Liquid.fg1)
                        .multilineTextAlignment(.trailing)
                }
            }

            if let notas = serial.notas, !notas.isEmpty {
                detailRow("Notas") {
                    Text(notas)
                        .font(.liquidSmall)
                        .foregroundStyle(Liquid.fg1)
                        .multilineTextAlignment(.trailing)
                }
            }

            if let tagRfid = serial.tagRfid {
                detailRow("Tag RFID") {
                    Text(tagRfid)
                        .liquidMonoData(11, color: Liquid.fg2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Button {
                var full = serial
                full.item = item.equipment
                router.push(.itemDetail(full))
            } label: {
                HStack {
                    Text("Ver condição completa")
                        .font(.liquidMono(12, weight: .medium))
                        .textCase(.uppercase)
                        .tracking(1.0)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Liquid.accentCyan)
                .padding(.top, Liquid.Space.sm)
            }
            .buttonStyle(.plain)
        }
        .transition(.opacity)
    }

    private func detailRow<Content: View>(
        _ label: String,
        @ViewBuilder value: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Liquid.Space.lg) {
            Text(label)
                .liquidLabel()
            Spacer(minLength: Liquid.Space.md)
            value()
        }
    }

    // MARK: - Unresolved Section

    @ViewBuilder
    private var unresolvedSection: some View {
        if !unresolved.isEmpty {
            VStack(alignment: .leading, spacing: Liquid.Space.md) {
                Text("Tags sem match")
                    .liquidLabel(Liquid.accentAmber)

                // Atalho mental pra Etiquetar: a tag virgem precisa de vinculo.
                HStack(spacing: Liquid.Space.sm) {
                    Image(systemName: "tag")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Liquid.accentViolet)
                    Text("Tags sem cadastro. Vincule em Etiquetar.")
                        .liquidSmall()
                }

                VStack(spacing: Liquid.Space.sm) {
                    ForEach(unresolved, id: \.self) { tag in
                        unresolvedRow(tag)
                    }
                }
            }
        }
    }

    private func unresolvedRow(_ tag: String) -> some View {
        HStack(spacing: Liquid.Space.md) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Liquid.accentAmber)

            VStack(alignment: .leading, spacing: Liquid.Space.xxs) {
                Text(tag)
                    .liquidMonoData(12, color: Liquid.fg2)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text("Tag não encontrada")
                    .liquidLabel(Liquid.fg3)
            }

            Spacer(minLength: Liquid.Space.sm)

            Button {
                router.push(.etiquetar(tag: tag))
            } label: {
                Text("Vincular")
                    .font(.liquidMono(11, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(1.0)
                    .foregroundStyle(Liquid.accentViolet)
                    .padding(.horizontal, Liquid.Space.md)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Liquid.accentViolet.opacity(0.15))
                            .overlay(Capsule().strokeBorder(Liquid.accentViolet.opacity(0.45), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Liquid.Space.lg)
        .padding(.vertical, Liquid.Space.md)
        .glassSurface(cornerRadius: Liquid.Radius.md, strong: true)
    }
}

// MARK: - Preview

#if DEBUG
struct LiquidScanResultView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LiquidScanResultView(
                resolved: previewResolved,
                unresolved: ["E2806894000050044CC15D2A", "E280689400005004DEADBEEF"]
            )
        }
        .preferredColorScheme(.dark)
    }

    static var previewResolved: [ResolvedItem] {
        let eq1 = Equipment(
            id: UUID(), nome: "Moving Head Wash", categoria: .iluminacao,
            marca: "Robe", modelo: "Robin 600", valorMercadoUnitario: 12000
        )
        let s1 = SerialNumber(
            id: UUID(), itemId: eq1.id, codigoInterno: "MMD-ILU-0042",
            tagRfid: "E2806894000050044CC15D1F", status: .disponivel,
            estado: .usado, desgaste: 4, valorAtual: 6240
        )

        let eq2 = Equipment(
            id: UUID(), nome: "Mesa de Som Digital", categoria: .audio,
            marca: "Yamaha", modelo: "TF5", valorMercadoUnitario: 28000
        )
        let s2 = SerialNumber(
            id: UUID(), itemId: eq2.id, codigoInterno: "MMD-AUD-0007",
            tagRfid: "E2806894000050044CC15D20", status: .emCampo,
            estado: .semiNovo, desgaste: 3, valorAtual: 14280,
            localizacao: "Evento Casa Petra"
        )

        return [
            ResolvedItem(serialNumber: s1, equipment: eq1),
            ResolvedItem(serialNumber: s2, equipment: eq2),
        ]
    }
}
#endif
