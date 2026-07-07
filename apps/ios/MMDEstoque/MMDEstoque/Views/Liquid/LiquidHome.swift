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
    @EnvironmentObject private var rfid: RFIDManager
    @StateObject private var vm: LiquidHomeViewModel

    init(apiClient: APIClient) {
        _vm = StateObject(wrappedValue: LiquidHomeViewModel(apiClient: apiClient))
    }

    // Os tiles carregam dado vivo: Receber mostra quantos itens estao em
    // campo, Etiquetar quantos ainda nao tem tag, Identificar o estado do
    // leitor. Despachar fica limpo (o hero ja carrega o proximo evento).
    private var jobs: [HomeJob] {
        [
            HomeJob(route: .identificarScan, icon: "dot.radiowaves.right",
                    title: "Identificar", subtitle: "Ler tag, ver item",
                    accent: Liquid.accentCyan, meta: readerMeta),
            HomeJob(route: .projetos(.aSair), icon: "shippingbox",
                    title: "Despachar", subtitle: "Saída pra campo",
                    accent: Liquid.accentAmber, meta: nil),
            HomeJob(route: .projetos(.emCampo), icon: "tray.and.arrow.down",
                    title: "Receber", subtitle: "Volta do campo",
                    accent: Liquid.accentGreen,
                    meta: countMeta(vm.counts.emCampo, dot: Liquid.accentAmber)),
            HomeJob(route: .etiquetar(tag: nil), icon: "tag",
                    title: "Etiquetar", subtitle: "Vincular tag nova",
                    accent: Liquid.accentViolet,
                    meta: countMeta(vm.counts.semTag, dot: Liquid.fg2)),
        ]
    }

    private var readerMeta: HomeJobMeta? {
        guard let reader = rfid.connectionState.readerInfo else { return nil }
        let battery = reader.batteryLevel.map { " \($0)%" } ?? ""
        return HomeJobMeta(text: "Leitor\(battery)", dot: Liquid.accentGreen)
    }

    private func countMeta(_ count: Int, dot: Color) -> HomeJobMeta? {
        guard vm.carregou, count > 0 else { return nil }
        return HomeJobMeta(text: "\(count)", dot: dot)
    }

    // Home sem scroll: tudo cabe na tela. O titulo saiu; os KPIs do estoque
    // ocupam a zona de header como instrumento (numeros borderless, sem card).
    // Pull-to-refresh saiu junto com o ScrollView; o load roda no .task.
    var body: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.xl) {
            header

            heroStack

            if let erro = vm.errorMessage {
                errorNote(erro)
            }

            Spacer(minLength: 0)

            jobsSection
        }
        .padding(.horizontal, Liquid.Space.xxl)
        .padding(.top, Liquid.Space.md)
        .padding(.bottom, 84)   // folga pra tab bar flutuante
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(TechnicalGridCanvas())
        .toolbar(.hidden, for: .navigationBar)
        .task { if !vm.carregou { await vm.load() } }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            (Text("MMD ").foregroundColor(Liquid.accentRed)
                + Text("Estoque").foregroundColor(Liquid.fg0))
                .font(.liquidSans(17, weight: .semibold))
                .tracking(-0.2)

            Spacer()

            Button { router.push(.config) } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Liquid.fg1)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Liquid.bg1))
                    .overlay(Circle().strokeBorder(Liquid.hairline, lineWidth: 1))
            }
            .accessibilityLabel("Configurações")
        }
    }

    // MARK: Hero Stack
    //
    // Card conectado: o hero do evento por cima e a regua de KPIs num
    // segundo card que desliza por baixo, em meio-tom (bgInset). As duas
    // pecas leem como um instrumento so: evento na frente, estoque atras.

    private let heroOverlap: CGFloat = 18

    private var heroStack: some View {
        VStack(spacing: -heroOverlap) {
            HomeHeroCard(
                evento: vm.proximoEvento,
                prontidao: vm.counts.prontidao,
                isLoading: vm.isLoading && !vm.carregou
            ) {
                if let evento = vm.proximoEvento { router.push(.packing(evento)) }
            }
            .zIndex(1)

            kpiAttachedCard
        }
    }

    private var kpiAttachedCard: some View {
        HStack(spacing: 0) {
            kpiStat(vm.carregou ? vm.counts.disponivel : nil, "disponível",
                    vm.counts.disponivel > 0 ? Liquid.accentGreen : Liquid.fg3)
            kpiDivider
            kpiStat(vm.carregou ? vm.counts.emCampo : nil, "em campo",
                    vm.counts.emCampo > 0 ? Liquid.accentAmber : Liquid.fg3)
            kpiDivider
            kpiStat(vm.carregou ? vm.counts.manutencao : nil, "manutenção",
                    vm.counts.manutencao > 0 ? Liquid.accentRed : Liquid.fg3)
        }
        .padding(.horizontal, Liquid.Space.xl)
        .padding(.top, heroOverlap + Liquid.Space.md)
        .padding(.bottom, Liquid.Space.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous)
                .fill(Liquid.bgInset)
                .overlay(
                    RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous)
                        .strokeBorder(Liquid.hairline, lineWidth: 1)
                )
        )
    }

    private var kpiDivider: some View {
        Rectangle()
            .fill(Liquid.hairline)
            .frame(width: 1, height: 28)
            .padding(.trailing, Liquid.Space.lg)
    }

    private func kpiStat(_ value: Int?, _ label: String, _ dot: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Group {
                if let value {
                    Text("\(value)")
                } else {
                    Text("–")
                }
            }
            .font(.liquidMono(18, weight: .medium))
            .foregroundStyle(value == nil ? Liquid.fg3 : Liquid.fg0)
            .contentTransition(.numericText())

            HStack(spacing: Liquid.Space.xs) {
                Circle().fill(dot).frame(width: 5, height: 5)
                Text(label)
                    .font(.liquidSans(11, weight: .medium))
                    .foregroundStyle(Liquid.fg2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            LiquidSectionHeader(title: "Ações")

            VStack(spacing: Liquid.Space.sm) {
                ForEach(jobs) { job in
                    HomeActionRow(job: job) { router.push(job.route) }
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
        .buttonStyle(.pressableCard)
        .disabled(evento == nil)
        .accessibilityLabel(evento.map { "Próximo evento: \($0.nome), abrir packing" } ?? "Nenhum evento confirmado")
    }

    private func eventoContent(_ evento: Project) -> some View {
        VStack(alignment: .leading, spacing: Liquid.Space.lg) {
            HStack(spacing: Liquid.Space.sm) {
                Text("PRÓXIMO EVENTO")
                    .font(.liquidMono(10, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Liquid.fg2)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Liquid.fg3)
            }

            HStack(alignment: .center, spacing: Liquid.Space.xl) {
                VStack(alignment: .leading, spacing: Liquid.Space.xs) {
                    Text(evento.nome)
                        .font(.liquidSans(24, weight: .semibold))
                        .tracking(-0.5)
                        .foregroundStyle(Liquid.fg0)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    if let cliente = evento.cliente {
                        Text(cliente)
                            .font(.liquidSans(14, weight: .regular))
                            .foregroundStyle(Liquid.fg2)
                    }
                }

                Spacer(minLength: Liquid.Space.md)

                ReadinessGauge(
                    progress: isLoading ? 0 : prontidao,
                    state: isLoading ? .partial : nil,
                    diameter: 76,
                    stroke: 6,
                    glow: false
                )
            }

            heroFooter(evento)
        }
    }

    /// Rodape de dados do hero: hairline + metadados mono lado a lado.
    private func heroFooter(_ evento: Project) -> some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            Rectangle()
                .fill(Liquid.hairline)
                .frame(height: 1)

            HStack(spacing: Liquid.Space.lg) {
                if let data = evento.dataInicioFormatado {
                    Label(data, systemImage: "calendar")
                        .liquidMonoData(11, color: Liquid.fg1)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                if let local = evento.local {
                    Label(local, systemImage: "mappin.and.ellipse")
                        .liquidMonoData(11, color: Liquid.fg2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
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

}

// MARK: - HomeJob

/// Dado vivo no canto do tile: contagem ou estado, com dot de cor funcional.
struct HomeJobMeta: Equatable {
    let text: String
    let dot: Color
}

struct HomeJob: Identifiable {
    let route: AppRoute
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    var meta: HomeJobMeta? = nil

    var id: AppRoute { route }
}

// MARK: - HomeActionRow
//
// Versao compacta do job pra home sem scroll com a tab bar: chip de icone,
// titulo, meta viva e chevron numa row fina. O tile 2x2 vive no sheet de
// acoes rapidas.

struct HomeActionRow: View {

    let job: HomeJob
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Liquid.Space.md) {
                Image(systemName: job.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Liquid.fg0)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Liquid.bg2)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(job.title)
                        .font(.liquidSans(15, weight: .semibold))
                        .foregroundStyle(Liquid.fg0)
                    Text(job.subtitle)
                        .font(.liquidSans(12, weight: .regular))
                        .foregroundStyle(Liquid.fg2)
                }

                Spacer(minLength: Liquid.Space.sm)

                if let meta = job.meta {
                    HStack(spacing: Liquid.Space.xs) {
                        Circle().fill(meta.dot).frame(width: 5, height: 5)
                        Text(meta.text)
                            .font(.liquidMono(11, weight: .medium))
                            .foregroundStyle(Liquid.fg1)
                    }
                    .padding(.horizontal, Liquid.Space.sm)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Liquid.bg2))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Liquid.fg3)
            }
            .padding(.horizontal, Liquid.Space.md)
            .padding(.vertical, Liquid.Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelSurface(cornerRadius: Liquid.Radius.md)
        }
        .buttonStyle(.pressableCard)
        .accessibilityLabel("\(job.title): \(job.subtitle)")
    }
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
                HStack(alignment: .top) {
                    Image(systemName: job.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Liquid.fg0)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Liquid.bg2)
                        )

                    Spacer(minLength: 0)

                    if let meta = job.meta {
                        HStack(spacing: Liquid.Space.xs) {
                            Circle().fill(meta.dot).frame(width: 5, height: 5)
                            Text(meta.text)
                                .font(.liquidMono(11, weight: .medium))
                                .foregroundStyle(Liquid.fg1)
                        }
                        .padding(.horizontal, Liquid.Space.sm)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Liquid.bg2))
                    }
                }

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
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .padding(Liquid.Space.lg)
            .panelSurface(cornerRadius: Liquid.Radius.lg)
        }
        .buttonStyle(.pressableCard)
        .accessibilityLabel("\(job.title): \(job.subtitle)")
    }
}
