import SwiftUI

// MARK: - LiquidTab
//
// As tres areas de navegacao persistente. As acoes de campo (identificar,
// despachar, receber, etiquetar) nao sao tabs: moram no botao "+" ao lado da
// barra, acessiveis de qualquer tab.

enum LiquidTab: Int, CaseIterable, Identifiable {
    case inicio
    case eventos
    case ajustes

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .inicio:  return "Início"
        case .eventos: return "Eventos"
        case .ajustes: return "Ajustes"
        }
    }

    var icon: String {
        switch self {
        case .inicio:  return "house"
        case .eventos: return "calendar"
        case .ajustes: return "gearshape"
        }
    }

    var activeIcon: String {
        switch self {
        case .inicio:  return "house.fill"
        case .eventos: return "calendar"
        case .ajustes: return "gearshape.fill"
        }
    }
}

// MARK: - LiquidTabBar
//
// Barra flutuante de vidro: capsule com as tabs e indicador que desliza via
// matchedGeometryEffect, mais o botao "+" circular de acoes rapidas. Vidro de
// verdade aqui: a barra flutua sobre conteudo que rola por baixo, entao o
// blur do material tem o que amostrar.

struct LiquidTabBar: View {

    @Binding var selection: LiquidTab
    var onPlus: () -> Void

    @Namespace private var indicator

    var body: some View {
        HStack(spacing: Liquid.Space.md) {
            HStack(spacing: 0) {
                ForEach(LiquidTab.allCases) { tab in
                    tabItem(tab)
                }
            }
            .padding(5)
            .background(glassBar(in: Capsule()))

            Button(action: onPlus) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Liquid.bg0)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Liquid.fg0))
                    .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.pressableCard)
            .accessibilityLabel("Ações rápidas")
            .tourAnchor(.plusButton)
        }
        .padding(.horizontal, Liquid.Space.xl)
        .padding(.bottom, Liquid.Space.xs)
    }

    private func tabItem(_ tab: LiquidTab) -> some View {
        Button { selection = tab } label: {
            VStack(spacing: 3) {
                Image(systemName: selection == tab ? tab.activeIcon : tab.icon)
                    .font(.system(size: 17, weight: .medium))
                Text(tab.title)
                    .font(.liquidSans(10, weight: .semibold))
            }
            .foregroundStyle(selection == tab ? Liquid.fg0 : Liquid.fg2)
            .frame(width: 76, height: 50)
            .background {
                if selection == tab {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .matchedGeometryEffect(id: "tab-indicator", in: indicator)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
        .tourAnchor(if: tab == .eventos ? .eventosTab : nil)
    }

    // Preenchimento solido no lugar do .ultraThinMaterial: a barra flutua
    // fixa sobre a home, entao o blur nao some, so custa. Um tom elevado
    // opaco + hairline + sombra ja da a leitura de peca destacada.
    private func glassBar<S: InsettableShape>(in shape: S) -> some View {
        shape
            .fill(Liquid.bg2)
            .overlay(shape.strokeBorder(Liquid.hairlineStrong, lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 10)
    }
}

// MARK: - QuickActionsSheet
//
// Lancador do "+": os quatro jobs de campo em tiles, de qualquer tab. Mesmo
// desenho dos tiles da home (chip de icone + titulo + descricao).

struct QuickActionsSheet: View {

    var onSelect: (AppRoute) -> Void

    private let actions: [HomeJob] = [
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
        VStack(alignment: .leading, spacing: Liquid.Space.lg) {
            LiquidSectionHeader(title: "Ações rápidas")

            LazyVGrid(columns: columns, spacing: Liquid.Space.md) {
                ForEach(actions) { job in
                    HomeActionTile(job: job) { onSelect(job.route) }
                }
            }
        }
        .padding(Liquid.Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Liquid.bg1.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
