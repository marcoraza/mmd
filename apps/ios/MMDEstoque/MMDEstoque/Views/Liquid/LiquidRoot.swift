import SwiftUI

// MARK: - AppRoute
//
// Contrato de navegacao: um enum so, com payload onde a tela precisa de
// contexto. Todos os destinos sao resolvidos na raiz (stack unico), entao nao
// ha NavigationStack aninhado. Hashable pro NavigationPath.

enum AppRoute: Hashable {
    case conectar
    case config
    case projetos(ProjectFilter)        // Despachar -> .aSair, Receber -> .emCampo
    case packing(Project)
    case checkout(Project)
    case retorno(Project)
    case identificarScan
    case scanResult(ScanResultPayload)
    case etiquetar(tag: String?)        // tag != nil = atalho oportunista
    case itemDetail(SerialNumber)
    case itemLost(SerialNumber)
}

// MARK: - ScanResultPayload
//
// Empacota o retorno do scan pra empurrar como rota. Hashable por id (evita
// exigir Hashable do ResolvedItem inteiro).

struct ScanResultPayload: Hashable {
    let resolved: [ResolvedItem]
    let unresolved: [String]

    static func == (lhs: ScanResultPayload, rhs: ScanResultPayload) -> Bool {
        lhs.unresolved == rhs.unresolved && lhs.resolved.map(\.id) == rhs.resolved.map(\.id)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(unresolved)
        hasher.combine(resolved.map(\.id))
    }
}

// MARK: - LiquidRoot
//
// Raiz do app Liquid. Banner de status do leitor sempre no topo (gate de tudo)
// e UM unico NavigationStack dirigido pelo LiquidRouter. Todos os destinos
// vivem aqui; as telas so empurram rotas.

struct LiquidRoot: View {

    @EnvironmentObject private var router: LiquidRouter

    var body: some View {
        ZStack {
            Liquid.bg0.ignoresSafeArea()

            VStack(spacing: 0) {
                ReaderStatusBar { router.push(.conectar) }

                NavigationStack(path: $router.path) {
                    LiquidHome()
                        .navigationDestination(for: AppRoute.self) { route in
                            destination(for: route)
                        }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .conectar:
            LiquidConnectReader()
        case .config:
            LiquidConfigView()
        case .projetos(let filter):
            LiquidProjectsListView(filter: filter) { project in
                router.push(filter == .emCampo ? .retorno(project) : .packing(project))
            }
        case .packing(let project):
            LiquidPackingListView(project: project) {
                router.push(.checkout(project))
            }
        case .checkout(let project):
            LiquidCheckoutValidationView(project: project)
        case .retorno(let project):
            LiquidReturnValidationView(project: project)
        case .identificarScan:
            IdentificarFlow()
        case .scanResult(let payload):
            LiquidScanResultView(resolved: payload.resolved, unresolved: payload.unresolved)
        case .etiquetar(let tag):
            LiquidVincularTagView(seedTag: tag)
        case .itemDetail(let serial):
            LiquidItemDetailView(serial: serial)
        case .itemLost(let serial):
            LiquidItemLostView(serial: serial)
        }
    }
}

// MARK: - ReaderStatusBar
//
// Pilula de vidro persistente: ponto colorido por estado, icone, label do
// status. Toque abre a tela de conectar. Status sempre visivel.

struct ReaderStatusBar: View {

    @EnvironmentObject private var rfid: RFIDManager
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Liquid.Space.sm) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
                    .liquidGlow(dotColor, radius: 6, opacity: 0.7)

                Image(systemName: rfid.statusIcon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(dotColor)

                Text(rfid.statusText)
                    .liquidLabel(Liquid.fg1)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Liquid.fg3)
            }
            .padding(.horizontal, Liquid.Space.lg)
            .padding(.vertical, Liquid.Space.md)
            .glassSurface(cornerRadius: Liquid.Radius.md, strong: true)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Liquid.Space.lg)
        .padding(.top, Liquid.Space.sm)
        .padding(.bottom, Liquid.Space.xs)
    }

    private var dotColor: Color {
        switch rfid.connectionState {
        case .connected:                return Liquid.accentGreen
        case .discovering, .connecting: return Liquid.accentAmber
        case .disconnected, .error:     return Liquid.accentRed
        }
    }
}
