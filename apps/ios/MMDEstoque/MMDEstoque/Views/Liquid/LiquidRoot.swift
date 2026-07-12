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
    @EnvironmentObject private var tour: TourController

    @EnvironmentObject private var apiClient: APIClient

    @State private var showQuickActions = false
    // Abas ja visitadas ficam vivas (opacity), pra nao recriar a tela nem
    // refazer o fetch a cada troca. Inicio nasce visitada.
    @State private var visitedTabs: Set<LiquidTab> = [.inicio]
    @State private var showLogin = false

    var body: some View {
        ZStack {
            Liquid.bg0.ignoresSafeArea()

            NavigationStack(path: $router.path) {
                tabRoot
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route)
                    }
            }
        }
        .overlay(alignment: .bottom) {
            if router.path.isEmpty {
                LiquidTabBar(selection: tabSelection) { showQuickActions = true }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Liquid.Motion.default, value: router.path.isEmpty)
        .sheet(isPresented: $showQuickActions) {
            QuickActionsSheet { route in
                showQuickActions = false
                router.push(route)
            }
            .presentationDetents([.height(400)])
            .presentationDragIndicator(.visible)
        }
        .overlayPreferenceValue(TourAnchorKey.self) { anchors in
            GeometryReader { proxy in
                TourOverlayContent(anchors: anchors, proxy: proxy)
            }
        }
        .onChange(of: tour.requestedTab) { newTab in
            guard let newTab else { return }
            tabSelection.wrappedValue = newTab
        }
        .onAppear(perform: startTourIfNeeded)
        .task { await evaluateAuthGate() }
        .onChange(of: apiClient.needsReauthentication) { needs in
            if needs { showLogin = true }
        }
        .fullScreenCover(isPresented: $showLogin) {
            LiquidLoginView {
                apiClient.needsReauthentication = false
                showLogin = false
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Auth Gate

    /// Supabase configurado e sem sessão: login por cima, sem resetar nav.
    @MainActor
    private func evaluateAuthGate() async {
        guard AppConfig.shared.isSupabaseConfigured else {
            showLogin = false
            return
        }
        let hasSession = await AuthSessionStore.shared.hasSession
        showLogin = !hasSession || apiClient.needsReauthentication
    }

    // MARK: Tour Kickoff

    private func startTourIfNeeded() {
        if ProcessInfo.processInfo.arguments.contains("-tourDemo") {
            AppConfig.shared.resetTours()
        }
        guard !AppConfig.shared.isTourDone(.orientacao) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            tour.start(TourDefinitions.orientacao)
        }
    }

    // MARK: Tabs

    /// As abas coexistem em camadas; a ativa fica opaca e recebe toque, as
    /// outras somem. Estado (view models, scroll, dado carregado) persiste,
    /// entao trocar de aba e um crossfade barato, sem recriar tela nem
    /// refazer fetch. So entra na arvore quem ja foi visitado (lazy).
    private var tabRoot: some View {
        ZStack {
            ForEach(LiquidTab.allCases) { tab in
                if visitedTabs.contains(tab) {
                    tabContent(tab)
                        .opacity(router.tab == tab ? 1 : 0)
                        .allowsHitTesting(router.tab == tab)
                }
            }
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: LiquidTab) -> some View {
        switch tab {
        case .inicio:
            LiquidHome()
        case .eventos:
            LiquidProjectsListView(filter: .todos) { project in
                router.push(project.status == .emCampo ? .retorno(project) : .packing(project))
            }
        case .ajustes:
            LiquidConfigView()
        }
    }

    /// Marca a aba como visitada e faz o crossfade curto.
    private var tabSelection: Binding<LiquidTab> {
        Binding(
            get: { router.tab },
            set: { newTab in
                guard newTab != router.tab else { return }
                visitedTabs.insert(newTab)
                withAnimation(.easeInOut(duration: 0.2)) {
                    router.tab = newTab
                }
            }
        )
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

// A pilula global do leitor (ReaderStatusBar) saiu: status de hardware em
// banner permanente e coisa de debug. O estado do leitor vive no contexto:
// rodape da home, CTA das telas de scan e Ajustes.
