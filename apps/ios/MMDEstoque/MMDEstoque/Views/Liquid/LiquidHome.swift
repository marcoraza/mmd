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
        GridItem(.flexible(), spacing: Liquid.Space.lg),
        GridItem(.flexible(), spacing: Liquid.Space.lg),
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

                StatusCountersRow(counts: vm.counts)

                AttentionQueue(alertas: vm.alertas, carregou: vm.carregou) { route in
                    router.push(route)
                }

                jobsSection
            }
            .padding(Liquid.Space.xxl)
            .padding(.bottom, Liquid.Space.vast)
        }
        .background(
            CausticBackground(intensity: .work, includesGreenOrb: true)
                .ignoresSafeArea()
        )
        .toolbar(.hidden, for: .navigationBar)
        .task { if !vm.carregou { await vm.load() } }
        .refreshable { await vm.load() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Liquid.Space.xs) {
                Text("MMD ESTOQUE")
                    .liquidLabel(Liquid.accentCyan)
                Text("Operação de campo")
                    .liquidTitle()
            }

            Spacer()

            Button { router.push(.config) } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Liquid.fg1)
                    .frame(width: 44, height: 44)
                    .glassSurface(cornerRadius: Liquid.Radius.md)
            }
            .accessibilityLabel("Configurações")
        }
        .padding(.top, Liquid.Space.sm)
    }

    private func errorNote(_ message: String) -> some View {
        HStack(spacing: Liquid.Space.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Liquid.accentAmber)
            Text(message)
                .liquidSmall()
                .foregroundStyle(Liquid.fg1)
                .lineLimit(2)
        }
        .padding(Liquid.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                .fill(Liquid.accentAmber.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                    .strokeBorder(Liquid.accentAmber.opacity(0.3), lineWidth: 1))
        )
    }

    // MARK: Jobs

    private var jobsSection: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.lg) {
            Text("O que você vai fazer")
                .liquidLabel()

            LazyVGrid(columns: columns, spacing: Liquid.Space.lg) {
                ForEach(jobs) { job in
                    HomeActionTile(job: job) { router.push(job.route) }
                }
            }
        }
    }
}

// MARK: - HomeHeroCard
//
// Hero do proximo evento a despachar. Ring de prontidao (glow) a esquerda,
// identidade do evento a direita. O card inteiro abre o packing do evento.

struct HomeHeroCard: View {

    let evento: Project?
    let prontidao: Double
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Liquid.Space.xl) {
                ReadinessGauge(
                    progress: isLoading ? 0 : prontidao,
                    state: isLoading ? .partial : nil,
                    diameter: 96,
                    stroke: 8,
                    glow: !isLoading,
                    caption: isLoading ? nil : "DISPONÍVEL"
                )

                VStack(alignment: .leading, spacing: Liquid.Space.xs) {
                    Text(isLoading ? "CARREGANDO" : "PRÓXIMO A DESPACHAR")
                        .liquidLabel(Liquid.accentViolet)

                    if let evento {
                        Text(evento.nome)
                            .liquidH3()
                            .foregroundStyle(Liquid.fg0)
                            .lineLimit(2)

                        if let cliente = evento.cliente {
                            Text(cliente)
                                .liquidSmall()
                        }

                        metaLine(evento)
                    } else {
                        Text(isLoading ? "Buscando eventos" : "Nenhum evento confirmado")
                            .liquidBody()
                            .foregroundStyle(Liquid.fg1)
                        Text(isLoading ? "Um instante" : "Confirme um projeto pra despachar")
                            .liquidSmall()
                    }
                }

                Spacer(minLength: 0)

                if evento != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Liquid.fg3)
                }
            }
            .padding(Liquid.Space.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(cornerRadius: Liquid.Radius.lg, strong: true)
            .liquidGlow(Liquid.accentViolet, radius: 22, opacity: 0.22)
        }
        .buttonStyle(.plain)
        .disabled(evento == nil)
        .accessibilityLabel(evento.map { "Próximo evento: \($0.nome), abrir packing" } ?? "Nenhum evento confirmado")
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

// MARK: - StatusCountersRow
//
// Quatro contadores de status do estoque: disponivel, em campo, manutencao,
// critico. Informativo, com cor por significado.

struct StatusCountersRow: View {

    let counts: StatusCounts

    var body: some View {
        HStack(spacing: Liquid.Space.md) {
            counter(counts.disponivel, "Disponível", Liquid.accentGreen)
            counter(counts.emCampo, "Em campo", Liquid.accentCyan)
            counter(counts.manutencao, "Manutenção", Liquid.accentAmber)
            counter(counts.critico, "Crítico", Liquid.accentRed)
        }
    }

    private func counter(_ value: Int, _ label: String, _ color: Color) -> some View {
        VStack(spacing: Liquid.Space.xxs) {
            Text("\(value)")
                .font(.liquidMono(26, weight: .medium))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .liquidGlow(color, radius: 8, opacity: value > 0 ? 0.35 : 0)
            Text(label)
                .liquidLabel()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Liquid.Space.lg)
        .glassSurface(cornerRadius: Liquid.Radius.md, strong: true)
    }
}

// MARK: - AttentionQueue
//
// Fila "precisa da sua atencao": alertas acionaveis derivados do estoque. Cada
// linha empurra a tela que resolve. Vazio (apos carregar) vira estado calmo.

struct AttentionQueue: View {

    let alertas: [HomeAlert]
    let carregou: Bool
    let onTap: (AppRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            Text("Precisa da sua atenção")
                .liquidLabel(alertas.isEmpty ? Liquid.fg2 : Liquid.accentAmber)

            if alertas.isEmpty {
                if carregou { calmRow }
            } else {
                VStack(spacing: Liquid.Space.sm) {
                    ForEach(alertas) { alerta in
                        alertRow(alerta)
                    }
                }
            }
        }
    }

    private var calmRow: some View {
        HStack(spacing: Liquid.Space.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Liquid.accentGreen)
            Text("Tudo em ordem, nada pendente")
                .liquidBody()
                .foregroundStyle(Liquid.fg1)
            Spacer(minLength: 0)
        }
        .padding(Liquid.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: Liquid.Radius.md, strong: true)
    }

    private func alertRow(_ alerta: HomeAlert) -> some View {
        Button {
            onTap(alerta.route)
        } label: {
            HStack(spacing: Liquid.Space.md) {
                Image(systemName: alerta.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(alerta.color)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: Liquid.Radius.sm, style: .continuous)
                            .fill(alerta.color.opacity(0.16))
                            .overlay(RoundedRectangle(cornerRadius: Liquid.Radius.sm, style: .continuous)
                                .strokeBorder(alerta.color.opacity(0.4), lineWidth: 1))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(alerta.title)
                        .font(.liquidSans(14, weight: .medium))
                        .foregroundStyle(Liquid.fg0)
                        .lineLimit(1)
                    Text(alerta.detail)
                        .liquidSmall()
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Liquid.fg3)
            }
            .padding(.horizontal, Liquid.Space.lg)
            .padding(.vertical, Liquid.Space.md)
            .glassSurface(cornerRadius: Liquid.Radius.md, strong: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(alerta.title). \(alerta.detail)")
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
// Tile de vidro alto, alvo de toque generoso. Icone na cor do job, titulo e
// uma linha de descricao.

struct HomeActionTile: View {

    let job: HomeJob
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Liquid.Space.md) {
                Image(systemName: job.icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(job.accent)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(job.accent.opacity(0.14)))
                    .liquidGlow(job.accent, radius: 12, opacity: 0.25)

                Spacer(minLength: Liquid.Space.lg)

                Text(job.title)
                    .liquidH3()
                    .foregroundStyle(Liquid.fg0)

                Text(job.subtitle)
                    .liquidSmall()
            }
            .frame(maxWidth: .infinity, minHeight: 158, alignment: .leading)
            .padding(Liquid.Space.xl)
            .glassSurface(cornerRadius: Liquid.Radius.lg)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(job.title): \(job.subtitle)")
    }
}
