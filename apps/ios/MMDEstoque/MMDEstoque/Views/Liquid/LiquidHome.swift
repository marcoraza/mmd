import SwiftUI

// MARK: - LiquidHome
//
// Cockpit operacional. Le o estoque real do Supabase via LiquidHomeViewModel e
// monta a Home em quatro blocos: hero do proximo evento (com ring de
// prontidao), linha de contadores de status, fila "precisa da sua atencao"
// acionavel, e os quatro jobs. Tudo aciona o LiquidRouter.
//
// Wrapper fino le o apiClient do ambiente e repassa pro conteudo dono do
// @StateObject do view model (mesmo padrao do retorno/check-out).

struct LiquidHome: View {

    @EnvironmentObject private var apiClient: APIClient

    var body: some View {
        LiquidHomeContent(apiClient: apiClient)
    }
}

// MARK: - Content

private struct LiquidHomeContent: View {

    @EnvironmentObject private var router: LiquidRouter
    @StateObject private var vm: LiquidHomeViewModel

    init(apiClient: APIClient) {
        _vm = StateObject(wrappedValue: LiquidHomeViewModel(apiClient: apiClient))
    }

    private let jobs: [HomeJob] = [
        HomeJob(route: .identificarScan, icon: "dot.radiowaves.right",
                title: "Identificar", subtitle: "Ler tag, ver item", accent: Liquid.accentCyan),
        HomeJob(route: .projetos(.aSair), icon: "shippingbox",
                title: "Despachar", subtitle: "Saída pra campo", accent: Liquid.accentAmber),
        HomeJob(route: .projetos(.emCampo), icon: "tray.and.arrow.down",
                title: "Receber", subtitle: "Volta do campo", accent: Liquid.accentGreen),
        HomeJob(route: .etiquetar(tag: nil), icon: "tag",
                title: "Etiquetar", subtitle: "Vincular tag nova", accent: Liquid.accentViolet),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: Liquid.Space.md),
        GridItem(.flexible(), spacing: Liquid.Space.md),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Liquid.Space.section) {
                header

                HomeHeroCard(
                    evento: vm.proximoEvento,
                    prontidao: vm.counts.prontidao,
                    isLoading: vm.isLoading && !vm.carregou
                ) {
                    if let evento = vm.proximoEvento { router.push(.packing(evento)) }
                }

                if let erro = vm.errorMessage {
                    errorNote(erro)
                }

                jobsSection
            }
            .padding(Liquid.Space.xxl)
            .padding(.bottom, Liquid.Space.vast)
        }
        .background(Liquid.bg0.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { if !vm.carregou { await vm.load() } }
        .refreshable { await vm.load() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Liquid.Space.sm) {
                (Text("MMD ").foregroundColor(Liquid.accentRed)
                    + Text("Estoque").foregroundColor(Liquid.fg2))
                    .font(.liquidSans(13, weight: .semibold))
                    .tracking(0.2)

                Text("Operação de campo")
                    .liquidLargeTitle()
            }

            Spacer()

            Button { router.push(.config) } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Liquid.fg1)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Liquid.bg1))
                    .overlay(Circle().strokeBorder(Liquid.hairline, lineWidth: 1))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Configurações")
        }
        .padding(.top, Liquid.Space.sm)
    }

    private func errorNote(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Liquid.Space.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Liquid.accentAmber)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sem conexão com o servidor")
                    .font(.liquidSans(14, weight: .medium))
                    .foregroundStyle(Liquid.fg1)
                Text(message)
                    .font(.liquidSans(12, weight: .regular))
                    .foregroundStyle(Liquid.fg3)
                    .lineLimit(1)
            }
        }
        .padding(Liquid.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelSurface(cornerRadius: Liquid.Radius.md)
    }

    // MARK: Jobs

    private var jobsSection: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.lg) {
            Text("Ações")
                .liquidSection()

            LazyVGrid(columns: columns, spacing: Liquid.Space.md) {
                ForEach(jobs) { job in
                    HomeActionTile(job: job) { router.push(job.route) }
                }
            }
        }
    }
}

// MARK: - HomeHeroCard
//
// Hero do proximo evento a despachar. Identidade do evento a esquerda, ring
// de prontidao a direita. O card inteiro abre o packing do evento. Sem
// evento, vira estado vazio desenhado (sem ring, sem vermelho).

struct HomeHeroCard: View {

    let evento: Project?
    let prontidao: Double
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Group {
                if let evento {
                    eventoContent(evento)
                } else {
                    emptyContent
                }
            }
            .padding(Liquid.Space.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelSurface(cornerRadius: Liquid.Radius.lg)
        }
        .buttonStyle(.plain)
        .disabled(evento == nil)
        .accessibilityLabel(evento.map { "Próximo evento: \($0.nome), abrir packing" } ?? "Nenhum evento confirmado")
    }

    private func eventoContent(_ evento: Project) -> some View {
        VStack(alignment: .leading, spacing: Liquid.Space.lg) {
            HStack {
                Text("Próximo evento")
                    .liquidSection()
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Liquid.fg3)
            }

            HStack(alignment: .center, spacing: Liquid.Space.xl) {
                VStack(alignment: .leading, spacing: Liquid.Space.xs) {
                    Text(evento.nome)
                        .liquidCardTitle()
                        .lineLimit(2)

                    if let cliente = evento.cliente {
                        Text(cliente)
                            .font(.liquidSans(13, weight: .regular))
                            .foregroundStyle(Liquid.fg2)
                    }

                    metaLine(evento)
                }

                Spacer(minLength: Liquid.Space.md)

                ReadinessGauge(
                    progress: isLoading ? 0 : prontidao,
                    state: isLoading ? .partial : nil,
                    diameter: 72,
                    stroke: 6,
                    glow: false
                )
            }
        }
    }

    private var emptyContent: some View {
        HStack(spacing: Liquid.Space.lg) {
            Image(systemName: "calendar")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Liquid.fg2)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Liquid.bg2)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(isLoading ? "Buscando eventos" : "Nenhum evento na fila")
                    .font(.liquidSans(16, weight: .semibold))
                    .foregroundStyle(Liquid.fg0)
                Text(isLoading ? "Um instante" : "Eventos confirmados aparecem aqui pra despacho")
                    .font(.liquidSans(13, weight: .regular))
                    .foregroundStyle(Liquid.fg2)
            }
        }
    }

    private func metaLine(_ evento: Project) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let data = evento.dataInicioFormatado {
                Label(data, systemImage: "calendar")
                    .liquidMonoData(11, color: Liquid.fg2)
                    .lineLimit(1)
            }
            if let local = evento.local {
                Label(local, systemImage: "mappin.and.ellipse")
                    .liquidMonoData(11, color: Liquid.fg2)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.top, Liquid.Space.xs)
    }
}

// MARK: - HomeJob

struct HomeJob: Identifiable {
    let route: AppRoute
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color

    var id: AppRoute { route }
}

// MARK: - HomeActionTile
//
// Tile de painel solido, alvo de toque generoso. Icone monocromatico em chip
// neutro (a cor do job vive nos fluxos, nao na home), titulo e descricao.

struct HomeActionTile: View {

    let job: HomeJob
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Liquid.Space.md) {
                Image(systemName: job.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Liquid.fg0)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Liquid.bg2)
                    )

                Spacer(minLength: Liquid.Space.md)

                VStack(alignment: .leading, spacing: 2) {
                    Text(job.title)
                        .font(.liquidSans(17, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(Liquid.fg0)

                    Text(job.subtitle)
                        .font(.liquidSans(13, weight: .regular))
                        .foregroundStyle(Liquid.fg2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
            .padding(Liquid.Space.lg)
            .panelSurface(cornerRadius: Liquid.Radius.lg)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(job.title): \(job.subtitle)")
    }
}
