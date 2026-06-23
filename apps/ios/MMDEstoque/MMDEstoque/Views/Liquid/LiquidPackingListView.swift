import SwiftUI

// MARK: - LiquidPackingListView
//
// Packing/detalhe do projeto, reskin Liquid de PackingListView. Header com
// nome, cliente, datas e um ring de prontidao (parte de zero: nada conferido
// ainda, a contagem real vem no scan da validacao). Abaixo, os itens
// esperados em cards de vidro com categoria, quantidade e desgaste. O botao de
// avancar devolve pelo callback `onAdvance`, pra trilha dona empurrar a
// validacao (check-out ou retorno) no NavigationStack da raiz.

struct LiquidPackingListView: View {

    let project: Project
    var onAdvance: (() -> Void)? = nil

    @EnvironmentObject private var apiClient: APIClient

    @State private var packingItems: [PackingListItem] = []
    @State private var serials: [SerialNumber] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        ZStack {
            CausticBackground(intensity: .work)

            content
        }
        .navigationTitle("Packing list")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if isLoading && packingItems.isEmpty {
            loadingState
        } else {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Liquid.Space.section) {
                        header

                        if packingItems.isEmpty {
                            emptyItemsCard
                        } else {
                            itemsSection
                        }
                    }
                    .padding(Liquid.Space.xxl)
                    .padding(.bottom, Liquid.Space.vast)
                }

                if onAdvance != nil {
                    advanceBar
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        GlassCard(strong: true) {
            VStack(alignment: .leading, spacing: Liquid.Space.lg) {
                HStack(alignment: .top, spacing: Liquid.Space.md) {
                    VStack(alignment: .leading, spacing: Liquid.Space.xs) {
                        Text(project.nome)
                            .liquidH2()
                            .foregroundStyle(Liquid.fg0)
                            .lineLimit(3)

                        if let cliente = project.cliente {
                            Text(cliente).liquidSmall()
                        }
                    }

                    Spacer(minLength: Liquid.Space.sm)

                    LiquidStatusBadge(projeto: project.status)
                }

                if let dateLine = dateLine {
                    HStack(spacing: Liquid.Space.sm) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Liquid.fg3)
                        Text(dateLine).liquidMonoData(11, color: Liquid.fg2)
                    }
                }

                Divider().overlay(Liquid.glassBorder)

                HStack(spacing: Liquid.Space.xl) {
                    ReadinessGauge(
                        progress: 0,
                        state: .missing,
                        diameter: Liquid.Ring.sizeMd,
                        stroke: Liquid.Ring.strokeMd,
                        caption: nil
                    )

                    VStack(alignment: .leading, spacing: Liquid.Space.xxs) {
                        Text("0/\(totalExpected)")
                            .font(.liquidMono(26, weight: .medium))
                            .foregroundStyle(Liquid.fg0)
                        Text("itens conferidos")
                            .liquidLabel(Liquid.fg2)
                        Text("Confira no scan da validação")
                            .liquidSmall()
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: Items

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.lg) {
            HStack {
                Text("Itens esperados").liquidLabel(Liquid.accentCyan)
                Spacer()
                Text("\(packingItems.count) linhas")
                    .liquidMonoData(11, color: Liquid.fg2)
            }
            .padding(.horizontal, Liquid.Space.xs)

            VStack(spacing: Liquid.Space.md) {
                ForEach(packingItems) { item in
                    packingItemCard(item)
                }
            }
        }
    }

    private func packingItemCard(_ item: PackingListItem) -> some View {
        GlassCard(cornerRadius: Liquid.Radius.md, strong: true, padding: Liquid.Space.lg) {
            VStack(alignment: .leading, spacing: Liquid.Space.md) {
                HStack(alignment: .top, spacing: Liquid.Space.md) {
                    VStack(alignment: .leading, spacing: Liquid.Space.xs) {
                        Text(item.displayName)
                            .liquidBody()
                            .foregroundStyle(Liquid.fg0)
                            .lineLimit(2)

                        if let categoria = item.item?.categoria {
                            LiquidCategoryBadge(categoria: categoria)
                        }
                    }

                    Spacer(minLength: Liquid.Space.sm)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("x\(item.quantidade)")
                            .font(.liquidMono(18, weight: .medium))
                            .foregroundStyle(Liquid.fg0)
                        Text("qtd")
                            .liquidLabel(Liquid.fg3)
                    }
                }

                if let desgaste = averageDesgaste(for: item) {
                    HStack(spacing: Liquid.Space.md) {
                        Text("Desgaste")
                            .liquidLabel(Liquid.fg2)
                        LiquidWearBar(level: desgaste)
                        Text("\(desgaste)/5")
                            .font(.liquidMono(11, weight: .medium))
                            .foregroundStyle(desgaste.liquidWearColor)
                    }
                }
            }
        }
    }

    // MARK: Advance Bar

    private var advanceBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(Liquid.glassBorder)

            Button { onAdvance?() } label: {
                HStack(spacing: Liquid.Space.sm) {
                    Image(systemName: advanceIcon)
                        .font(.system(size: 15, weight: .medium))
                    Text(advanceLabel)
                        .font(.liquidMono(14, weight: .medium))
                        .textCase(.uppercase)
                        .tracking(1.5)
                }
                .foregroundStyle(Liquid.bg0)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Liquid.Space.lg)
                .background {
                    let shape = RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous)
                    shape.fill(advanceTint).liquidGlow(advanceTint, radius: 16, opacity: 0.4)
                }
            }
            .buttonStyle(.plain)
            .padding(Liquid.Space.xxl)
        }
        .background(Liquid.bg0.opacity(0.35))
    }

    private var advanceLabel: String {
        project.status == .emCampo ? "Iniciar retorno" : "Iniciar check-out"
    }

    private var advanceIcon: String {
        project.status == .emCampo ? "tray.and.arrow.down" : "shippingbox"
    }

    private var advanceTint: Color {
        project.status == .emCampo ? Liquid.accentGreen : Liquid.accentAmber
    }

    // MARK: States

    private var loadingState: some View {
        VStack(spacing: Liquid.Space.lg) {
            ProgressView().tint(Liquid.fg2)
            Text("Carregando packing list").liquidLabel()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyItemsCard: some View {
        GlassCard {
            VStack(spacing: Liquid.Space.md) {
                Image(systemName: error == nil ? "shippingbox" : "exclamationmark.triangle")
                    .font(.system(size: 30, weight: .thin))
                    .foregroundStyle(error == nil ? Liquid.fg3 : Liquid.accentAmber)
                Text(error == nil ? "Packing list vazia" : "Falha ao carregar")
                    .liquidH3()
                Text(error ?? "Adicione itens pelo painel web.")
                    .liquidBody()
                    .foregroundStyle(Liquid.fg2)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Helpers

    private var totalExpected: Int {
        packingItems.reduce(0) { $0 + $1.quantidade }
    }

    private var dateLine: String? {
        switch (project.dataInicioFormatado, project.dataFimFormatado) {
        case let (inicio?, fim?): return "\(inicio) até \(fim)"
        case let (inicio?, nil):  return inicio
        case let (nil, fim?):     return fim
        default:                  return nil
        }
    }

    /// Desgaste medio dos seriais designados a esta linha, quando ja resolvidos.
    private func averageDesgaste(for item: PackingListItem) -> Int? {
        guard let ids = item.serialNumbersDesignados, !ids.isEmpty else { return nil }
        let matched = serials.filter { ids.contains($0.id) }
        guard !matched.isEmpty else { return nil }
        let sum = matched.reduce(0) { $0 + $1.desgaste }
        return Int((Double(sum) / Double(matched.count)).rounded())
    }

    // MARK: Data

    private func load() async {
        isLoading = true
        error = nil
        do {
            packingItems = try await apiClient.fetchPackingList(projectId: project.id)
            let designated = packingItems.flatMap { $0.serialNumbersDesignados ?? [] }
            if !designated.isEmpty {
                serials = try await apiClient.fetchSerialsByIds(Array(Set(designated)))
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Preview

#if DEBUG
struct LiquidPackingListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LiquidPackingListView(
                project: Project(
                    id: UUID(),
                    nome: "Festival de Verao",
                    cliente: "Producoes XYZ",
                    dataInicio: "2026-04-15",
                    dataFim: "2026-04-17",
                    local: "Praia do Forte",
                    status: .confirmado
                ),
                onAdvance: {}
            )
            .environmentObject(APIClient())
        }
        .preferredColorScheme(.dark)
    }
}
#endif
