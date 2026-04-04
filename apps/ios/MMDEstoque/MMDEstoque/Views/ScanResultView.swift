import SwiftUI

// MARK: - ScanResultView

/// Displays resolved RFID scan results. Hero summary with Doto numbers,
/// card-less resolved items with expand-to-detail, and subdued unresolved tags.
/// Nothing Design System, pure dark, no system colors.
struct ScanResultView: View {

    let resolvedItems: [ResolvedItem]
    let unresolvedTags: [String]

    @State private var expandedItemId: UUID?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSummary
                resolvedSection
                unresolvedSection

                // Bottom breathing room
                Spacer()
                    .frame(height: NDSpacing.xWide)
            }
        }
        .background(Color.ndBlack)
        .navigationTitle("Resultado")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Hero Summary

    private var heroSummary: some View {
        VStack(spacing: NDSpacing.base) {
            Spacer()
                .frame(height: NDSpacing.vast)

            // Resolved count
            HStack(alignment: .firstTextBaseline, spacing: NDSpacing.compact) {
                Text("\(resolvedItems.count)")
                    .font(.displayLG)
                    .foregroundStyle(Color.ndTextDisplay)

                Text("RESOLVIDOS")
                    .font(.spaceMono(14))
                    .tracking(14 * 0.08)
                    .foregroundStyle(Color.ndTextPrimary)
            }

            // Unresolved count (if any)
            if !unresolvedTags.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: NDSpacing.base) {
                    Text("\(unresolvedTags.count)")
                        .font(.spaceMono(14))
                        .foregroundStyle(Color.ndAccent)

                    Text("SEM MATCH")
                        .font(.spaceMono(14))
                        .tracking(14 * 0.08)
                        .foregroundStyle(Color.ndAccent)
                }
            }

            Spacer()
                .frame(height: NDSpacing.vast)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Resolved Section

    @ViewBuilder
    private var resolvedSection: some View {
        if !resolvedItems.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Section label
                Text("RESOLVIDOS")
                    .ndLabelSmall()
                    .padding(.horizontal, NDSpacing.medium)
                    .padding(.bottom, NDSpacing.compact)

                // 1px top border
                Rectangle()
                    .fill(Color.ndBorder)
                    .frame(height: 1)

                // Item list
                ForEach(resolvedItems) { item in
                    resolvedItemRow(item)

                    Rectangle()
                        .fill(Color.ndBorder)
                        .frame(height: 1)
                }
            }
        }
    }

    private func resolvedItemRow(_ item: ResolvedItem) -> some View {
        let isExpanded = expandedItemId == item.id

        return VStack(spacing: 0) {
            // Main row (always visible, tappable)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedItemId = isExpanded ? nil : item.id
                }
            } label: {
                HStack(spacing: NDSpacing.compact) {
                    // Left: name + code
                    VStack(alignment: .leading, spacing: NDSpacing.tight) {
                        Text(item.displayName)
                            .font(.ndBody)
                            .foregroundStyle(Color.ndTextPrimary)
                            .lineLimit(1)

                        HStack(spacing: NDSpacing.base) {
                            Text(item.codigoInterno)
                                .font(.ndCaption)
                                .foregroundStyle(Color.ndTextSecondary)

                            if let marca = item.equipment.marca,
                               let modelo = item.equipment.modelo {
                                Text("\(marca) \(modelo)")
                                    .font(.spaceGrotesk(12))
                                    .foregroundStyle(Color.ndTextDisabled)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    // Badges
                    CategoriaBadge(text: item.categoria.prefix, color: item.categoria.color)

                    StatusBadge(text: item.statusLabel, color: item.serialNumber.status.color)
                }
                .padding(.horizontal, NDSpacing.medium)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            // Expanded detail panel
            if isExpanded {
                expandedDetails(item)
            }
        }
    }

    // MARK: - Expanded Details

    private func expandedDetails(_ item: ResolvedItem) -> some View {
        VStack(spacing: 0) {
            // Separator
            Rectangle()
                .fill(Color.ndBorder)
                .frame(height: 1)
                .padding(.horizontal, NDSpacing.medium)

            VStack(spacing: NDSpacing.compact) {
                // Estado
                detailRow("ESTADO") {
                    Text(item.serialNumber.estado.displayName)
                        .font(.spaceMono(14))
                        .foregroundStyle(Color.ndTextPrimary)
                }

                // Desgaste with WearBar
                detailRow("DESGASTE") {
                    HStack(spacing: NDSpacing.base) {
                        WearBar(level: item.serialNumber.desgaste)
                            .frame(width: 80)
                        Text("\(item.serialNumber.desgaste)/5")
                            .font(.spaceMono(14))
                            .foregroundStyle(item.serialNumber.desgaste.wearColor)
                    }
                }

                // Valor Atual
                if let valor = item.valorFormatado {
                    detailRow("VALOR ATUAL") {
                        Text(valor)
                            .font(.spaceMono(14))
                            .foregroundStyle(Color.ndTextPrimary)
                    }
                }

                // Localizacao
                if let localizacao = item.serialNumber.localizacao {
                    detailRow("LOCALIZACAO") {
                        Text(localizacao)
                            .font(.spaceMono(14))
                            .foregroundStyle(Color.ndTextPrimary)
                    }
                }

                // Notas
                if let notas = item.serialNumber.notas, !notas.isEmpty {
                    detailRow("NOTAS") {
                        Text(notas)
                            .font(.spaceGrotesk(14))
                            .foregroundStyle(Color.ndTextPrimary)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // Tag RFID
                if let tagRfid = item.serialNumber.tagRfid {
                    detailRow("TAG RFID") {
                        Text(tagRfid)
                            .font(.spaceMono(12))
                            .foregroundStyle(Color.ndTextSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, NDSpacing.medium)
            .padding(.vertical, NDSpacing.medium)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func detailRow<Content: View>(_ label: String, @ViewBuilder value: () -> Content) -> some View {
        HStack {
            Text(label)
                .ndLabelSmall()

            Spacer()

            value()
        }
    }

    // MARK: - Unresolved Section

    @ViewBuilder
    private var unresolvedSection: some View {
        if !unresolvedTags.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Gap between sections
                Spacer()
                    .frame(height: NDSpacing.wide)

                // 1px border
                Rectangle()
                    .fill(Color.ndBorder)
                    .frame(height: 1)

                Spacer()
                    .frame(height: NDSpacing.wide)

                // Section label in ndAccent
                Text("NAO RESOLVIDOS")
                    .ndLabelSmallAccent(Color.ndAccent)
                    .padding(.horizontal, NDSpacing.medium)
                    .padding(.bottom, NDSpacing.compact)

                // 1px top border
                Rectangle()
                    .fill(Color.ndBorder)
                    .frame(height: 1)

                // Tag rows
                ForEach(unresolvedTags, id: \.self) { tag in
                    unresolvedTagRow(tag)

                    Rectangle()
                        .fill(Color.ndBorder)
                        .frame(height: 1)
                }
            }
        }
    }

    private func unresolvedTagRow(_ tag: String) -> some View {
        VStack(alignment: .leading, spacing: NDSpacing.tight) {
            Text(tag)
                .font(.spaceMono(14))
                .foregroundStyle(Color.ndTextDisabled)
                .lineLimit(1)

            Text("TAG NAO ENCONTRADA")
                .font(.ndLabelSm)
                .textCase(.uppercase)
                .tracking(9 * 0.08)
                .foregroundStyle(Color.ndTextDisabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, NDSpacing.medium)
        .padding(.vertical, 14)
    }
}

// MARK: - Preview

#if DEBUG
struct ScanResultView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ScanResultView(
                resolvedItems: previewResolvedItems,
                unresolvedTags: ["E2806894000050044CC15D2A", "E280689400005004DEADBEEF"]
            )
        }
        .preferredColorScheme(.dark)
    }

    static var previewResolvedItems: [ResolvedItem] {
        let equipment1 = Equipment(
            id: UUID(),
            nome: "Moving Head Wash",
            categoria: .iluminacao,
            marca: "Robe",
            modelo: "Robin 600",
            valorMercadoUnitario: 12000.0
        )

        let serial1 = SerialNumber(
            id: UUID(),
            itemId: equipment1.id,
            codigoInterno: "MMD-ILU-0042",
            tagRfid: "E2806894000050044CC15D1F",
            status: .disponivel,
            estado: .usado,
            desgaste: 4,
            valorAtual: 6240.0
        )

        let equipment2 = Equipment(
            id: UUID(),
            nome: "Mesa de Som Digital",
            categoria: .audio,
            marca: "Yamaha",
            modelo: "TF5",
            valorMercadoUnitario: 28000.0
        )

        let serial2 = SerialNumber(
            id: UUID(),
            itemId: equipment2.id,
            codigoInterno: "MMD-AUD-0007",
            tagRfid: "E2806894000050044CC15D20",
            status: .emCampo,
            estado: .semiNovo,
            desgaste: 3,
            valorAtual: 14280.0,
            localizacao: "Evento Casa Petra"
        )

        let equipment3 = Equipment(
            id: UUID(),
            nome: "Painel LED",
            categoria: .video,
            marca: "Absen",
            modelo: "PL2.9",
            valorMercadoUnitario: 8500.0
        )

        let serial3 = SerialNumber(
            id: UUID(),
            itemId: equipment3.id,
            codigoInterno: "MMD-VID-0015",
            tagRfid: "E2806894000050044CC15D21",
            status: .manutencao,
            estado: .usado,
            desgaste: 2,
            valorAtual: 2210.0,
            notas: "Modulo B3 com pixel morto, aguardando peca"
        )

        return [
            ResolvedItem(serialNumber: serial1, equipment: equipment1),
            ResolvedItem(serialNumber: serial2, equipment: equipment2),
            ResolvedItem(serialNumber: serial3, equipment: equipment3),
        ]
    }
}
#endif
