import SwiftUI

// MARK: - PackingMode

enum PackingMode { case lista, mapa }

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
    @State private var mode: PackingMode = .lista

    var body: some View {
        Group {
            if mode == .lista {
                ZStack {
                    TechnicalGridCanvas()
                    content
                }
            } else {
                LiquidPackingMapView(project: project)
            }
        }
        .navigationTitle("Packing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LiquidPillToggle(selection: $mode, options: [(.lista, "Lista"), (.mapa, "Mapa")])
            }
        }
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
    //
    // Card conectado: identidade do evento por cima, progresso de conferencia
    // no card acoplado em meio-tom por baixo (mesmo padrao do hero da home).

    private let headerOverlap: CGFloat = 18

    private var header: some View {
        VStack(spacing: -headerOverlap) {
            identityCard
                .zIndex(1)

            progressAttachedCard
        }
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.lg) {
            HStack(alignment: .top, spacing: Liquid.Space.md) {
                VStack(alignment: .leading, spacing: Liquid.Space.xs) {
                    Text("EVENTO")
                        .font(.liquidMono(10, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(Liquid.fg2)
                        .padding(.bottom, Liquid.Space.xs)

                    Text(project.nome)
                        .font(.liquidSans(22, weight: .semibold))
                        .tracking(-0.4)
                        .foregroundStyle(Liquid.fg0)
                        .lineLimit(3)

                    if let cliente = project.cliente {
                        Text(cliente)
                            .font(.liquidSans(13, weight: .regular))
                            .foregroundStyle(Liquid.fg2)
                    }
                }

                Spacer(minLength: Liquid.Space.sm)

                LiquidStatusBadge(projeto: project.status)
            }

            if let dateLine = dateLine {
                Label(dateLine, systemImage: "calendar")
                    .liquidMonoData(11, color: Liquid.fg2)
                    .lineLimit(1)
            }
        }
        .padding(Liquid.Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelSurface(cornerRadius: Liquid.Radius.lg)
    }

    private var progressAttachedCard: some View {
        HStack(spacing: Liquid.Space.lg) {
            ReadinessGauge(
                progress: 0,
                state: .missing,
                diameter: 48,
                stroke: 5,
                caption: nil
            )

            VStack(alignment: .leading, spacing: 2) {
                (Text("0").foregroundColor(Liquid.fg0)
                    + Text("/\(totalExpected)").foregroundColor(Liquid.fg2))
                    .font(.liquidMono(17, weight: .medium))

                Text("Conferidos no scan da validação")
                    .font(.liquidSans(12, weight: .regular))
                    .foregroundStyle(Liquid.fg2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Liquid.Space.xl)
        .padding(.top, headerOverlap + Liquid.Space.md)
        .padding(.bottom, Liquid.Space.md)
        .frame(maxWidth: .infinity)
        .panelSurface(cornerRadius: Liquid.Radius.lg, tone: .inset)
    }

    // MARK: Items

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.lg) {
            LiquidSectionHeader(
                title: "Itens esperados",
                trailing: "\(packingItems.count) linhas"
            )
            .padding(.horizontal, Liquid.Space.xs)

            VStack(spacing: Liquid.Space.md) {
                ForEach(packingItems) { item in
                    packingItemCard(item)
                }
            }
        }
    }

    private func packingItemCard(_ item: PackingListItem) -> some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            HStack(alignment: .top, spacing: Liquid.Space.md) {
                VStack(alignment: .leading, spacing: Liquid.Space.sm) {
                    Text(item.displayName)
                        .font(.liquidSans(15, weight: .medium))
                        .foregroundStyle(Liquid.fg0)
                        .lineLimit(2)

                    if let categoria = item.item?.categoria {
                        LiquidCategoryBadge(categoria: categoria)
                    }
                }

                Spacer(minLength: Liquid.Space.sm)

                (Text("×").foregroundColor(Liquid.fg3)
                    + Text("\(item.quantidade)").foregroundColor(Liquid.fg0))
                    .font(.liquidMono(18, weight: .medium))
            }

            if let desgaste = averageDesgaste(for: item) {
                HStack(spacing: Liquid.Space.md) {
                    Text("Desgaste")
                        .font(.liquidSans(11, weight: .medium))
                        .foregroundStyle(Liquid.fg2)
                    LiquidWearBar(level: desgaste)
                    Text("\(desgaste)/5")
                        .font(.liquidMono(11, weight: .medium))
                        .foregroundStyle(desgaste.liquidWearColor)
                }
            }
        }
        .padding(Liquid.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelSurface(cornerRadius: Liquid.Radius.md)
    }

    // MARK: Advance Bar

    private var advanceBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Liquid.hairline)
                .frame(height: 1)

            Button { onAdvance?() } label: {
                HStack(spacing: Liquid.Space.sm) {
                    Image(systemName: advanceIcon)
                        .font(.system(size: 15, weight: .semibold))
                    Text(advanceLabel)
                        .font(.liquidSans(16, weight: .semibold))
                }
                .foregroundStyle(Liquid.bg0)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                        .fill(advanceTint)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Liquid.Space.xxl)
            .padding(.vertical, Liquid.Space.lg)
        }
        .background(Liquid.bg0)
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
            Text("Carregando packing list")
                .font(.liquidSans(14, weight: .medium))
                .foregroundStyle(Liquid.fg2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyItemsCard: some View {
        VStack(spacing: Liquid.Space.md) {
            Image(systemName: error == nil ? "shippingbox" : "exclamationmark.triangle")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(error == nil ? Liquid.fg2 : Liquid.accentAmber)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Liquid.bg2)
                )

            Text(error == nil ? "Packing list vazia" : "Falha ao carregar")
                .font(.liquidSans(16, weight: .semibold))
                .foregroundStyle(Liquid.fg0)

            Text(error ?? "Adicione itens pelo painel web.")
                .font(.liquidSans(13, weight: .regular))
                .foregroundStyle(Liquid.fg2)
                .multilineTextAlignment(.center)
        }
        .padding(Liquid.Space.section)
        .frame(maxWidth: .infinity)
        .panelSurface(cornerRadius: Liquid.Radius.lg)
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
