import SwiftUI

// MARK: - LiquidHome
//
// Lancador por job (decisao 3): quatro acoes grandes, gloves-friendly, mais a
// entrada de Config. Cada acao empurra sua rota no NavigationStack da raiz.

struct LiquidHome: View {

    @EnvironmentObject private var router: LiquidRouter

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

                LazyVGrid(columns: columns, spacing: Liquid.Space.lg) {
                    ForEach(jobs) { job in
                        HomeActionTile(job: job) { router.push(job.route) }
                    }
                }
            }
            .padding(Liquid.Space.xxl)
            .padding(.bottom, Liquid.Space.vast)
        }
        .background(
            CausticBackground(intensity: .work, includesGreenOrb: true)
                .ignoresSafeArea()
        )
        .toolbar(.hidden, for: .navigationBar)
    }

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
