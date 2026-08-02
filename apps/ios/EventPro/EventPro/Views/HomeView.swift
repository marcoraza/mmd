import SwiftUI

/// Raiz autenticada da Home 2.0: quatro abas (Início, Eventos, Catálogo,
/// Ler tag) na barra de tinta cheia (opção 1). Ajustes saiu da barra e vive
/// no avatar do topo do Início.
struct HomeView: View {
    // Abre em Eventos: e a tela do grill; a Home propria ainda nao foi
    // desenhada (proxima fatia).
    @State private var tab: Tab = .eventos

    enum Tab: Int {
        case inicio, eventos, catalogo, lerTag
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .inicio:
                    AbaEmConstrucao(
                        icone: "house",
                        titulo: "Início",
                        texto: "A Home do Event Pro chega numa próxima fatia. Por enquanto a operação vive em Eventos."
                    )
                case .eventos:
                    EventosView()
                case .catalogo:
                    AbaEmConstrucao(
                        icone: "shippingbox",
                        titulo: "Catálogo",
                        texto: "O catálogo de equipamentos chega numa próxima fatia desta frente."
                    )
                case .lerTag:
                    AbaEmConstrucao(
                        icone: "viewfinder",
                        titulo: "Ler tag",
                        texto: "A leitura de tag chega junto com a frente RFID e o leitor RFD40."
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Fade de 104pt do transparente ao papel, atras da barra.
            LinearGradient(
                stops: [
                    .init(color: EP.paper.opacity(0), location: 0),
                    .init(color: EP.paper, location: 0.62),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 104)
            .allowsHitTesting(false)

            TabBar(active: $tab)
                .padding(.bottom, 26)
        }
        .ignoresSafeArea(edges: .bottom)
        .background(EP.paper)
    }
}

// MARK: - Barra inferior (opção 1: sem cápsula, ativo em tinta cheia)
//
// A aba ativa expande mostrando ícone mais nome; as apagadas são só glifo.
// Estado por peso: a pílula de tinta é o elemento mais pesado da tela.

private struct TabBar: View {
    @Binding var active: HomeView.Tab

    private let items: [(tab: HomeView.Tab, icon: String, label: String)] = [
        (.inicio, "house", "Início"),
        (.eventos, "calendar", "Eventos"),
        (.catalogo, "shippingbox", "Catálogo"),
        (.lerTag, "viewfinder", "Ler tag"),
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items, id: \.tab) { item in
                aba(item)
            }
        }
    }

    private func aba(_ item: (tab: HomeView.Tab, icon: String, label: String)) -> some View {
        let ativa = active == item.tab
        return Button {
            withAnimation(EP.abaCapsula) { active = item.tab }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .regular))
                if ativa {
                    Text(item.label)
                        .font(EP.abaRotulo())
                        .fixedSize()
                        .transition(.opacity)
                }
            }
            .foregroundStyle(ativa ? EP.paper : EP.tabApagado)
            .padding(.leading, ativa ? 14 : 13)
            .padding(.trailing, ativa ? 17 : 13)
            .frame(height: 46)
            .background {
                if ativa {
                    Capsule()
                        .fill(EP.ink)
                        .shadow(color: Color(hexRGB: 0x14161A).opacity(0.22), radius: 10, y: 8)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
        .accessibilityAddTraits(ativa ? .isSelected : [])
    }
}

// MARK: - EventosView
//
// A tela do grill (o protótipo abre com a aba Eventos ativa): topo
// tipográfico com avatar, frase única de dados, mapa real do destino e
// agenda de ordem fixa. Distância em km fica de fora até existir rota.

struct EventosView: View {
    @EnvironmentObject private var api: APIClient

    var body: some View {
        EventosContent(apiClient: api)
    }
}

private struct EventosContent: View {

    @StateObject private var vm: HomeViewModel
    @StateObject private var location: EventLocationViewModel
    @EnvironmentObject private var auth: AuthState
    @State private var mostraAjustes = false
    @State private var mostraDestino = false

    init(apiClient: APIClient) {
        _vm = StateObject(wrappedValue: HomeViewModel(apiClient: apiClient))
        _location = StateObject(
            wrappedValue: EventLocationViewModel(
                searcher: MapKitPlaceSearcher(),
                store: APIClientDestinoStore(client: apiClient),
                canEdit: false
            )
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    topo
                        .padding(.horizontal, EP.padTela)
                        .padding(.top, EP.s1)

                    frase
                        .padding(.horizontal, EP.padTela)
                        .padding(.top, EP.s3)

                    if let erro = vm.errorMessage {
                        errorNote(erro)
                            .padding(.horizontal, EP.padTela)
                            .padding(.top, EP.s4)
                    }

                    MapaHome(
                        eventos: vm.agenda,
                        selecionado: vm.selecionadoIndex,
                        aoArrastar: { passo in vm.selecionar(vm.selecionadoIndex + passo) },
                        aoTocar: { abrirDestino() }
                    )
                    .padding(.top, EP.s4)

                    agendaSection
                        .padding(.horizontal, EP.padTela - 12)
                }
                .padding(.bottom, EP.padBarra)
            }
            .background(EP.paper)
            .task {
                guard !vm.carregou else { return }
                await vm.load()
                // Ao abrir, a linha destacada entra na dobra (a agenda
                // completa pode deixar o proximo confirmado la embaixo).
                if let id = vm.selecionado?.id {
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    proxy.scrollTo("agenda-\(id)", anchor: .center)
                }
            }
            .sheet(isPresented: $mostraAjustes) { SettingsView() }
            .sheet(isPresented: $mostraDestino) {
                EventoDestinoSheet(location: location) {
                    mostraDestino = false
                }
            }
            .onAppear {
                location.onPinPersisted = { projectId, pin in
                    vm.applyDestino(projectId: projectId, pin: pin)
                }
            }
            .onChange(of: vm.selecionadoIndex) { _, _ in
                rebindLocation()
            }
            .onChange(of: vm.carregou) { _, ready in
                if ready { rebindLocation() }
            }
        }
    }

    private func abrirDestino() {
        rebindLocation()
        mostraDestino = true
    }

    private func rebindLocation() {
        guard let projeto = vm.selecionado else { return }
        location.bind(project: projeto, canEdit: vm.canEditDestino)
    }

    // MARK: Topo tipográfico

    private var topo: some View {
        HStack(alignment: .top, spacing: EP.s4) {
            VStack(alignment: .leading, spacing: 0) {
                Text(kicker)
                    .font(EP.kicker())
                    .foregroundStyle(EP.ink3)

                // Altura reservada pra 3 linhas de display (nome ate 2 +
                // local 1): nome curto e nome longo ocupam o mesmo bloco e
                // o mapa nao pula quando a selecao troca.
                VStack(alignment: .leading, spacing: 0) {
                    Text(tituloDisplay)
                        .font(EP.display())
                        .tracking(EP.displayTracking)
                        .lineSpacing(34 * 0.04)
                        .foregroundStyle(EP.ink)
                        .lineLimit(2)
                    if !localDisplay.isEmpty {
                        Text(localDisplay)
                            .font(EP.display())
                            .tracking(EP.displayTracking)
                            .foregroundStyle(EP.ink3)
                            .lineLimit(1)
                    }
                }
                .frame(height: 120, alignment: .topLeading)
                .padding(.top, 7)
            }
            Spacer(minLength: 0)

            Button {
                mostraAjustes = true
            } label: {
                Text(avatarLetra)
                    .font(.custom("InterTight", size: 13).weight(.semibold))
                    .foregroundStyle(EP.paper)
                    .frame(width: 34, height: 34)
                    .background(EP.ink, in: Circle())
                    .padding(.top, 3)
                    .contentShape(Rectangle())
            }
            .buttonStyle(EPPressStyle())
            .accessibilityLabel("Ajustes")
        }
    }

    private var avatarLetra: String {
        auth.email?.first.map { String($0).uppercased() } ?? "•"
    }

    private var kicker: String {
        guard vm.carregou else { return vm.isLoading ? "Carregando agenda" : "Agenda" }
        guard let evento = vm.selecionado else { return "Agenda vazia" }
        if evento.status == .emCampo { return "Em campo agora" }
        guard let dias = diasAte(evento) else { return "Sem data definida" }
        if dias < 0 { return "Evento passado" }
        if dias == 0 { return "Sai hoje" }
        if dias == 1 { return "Sai amanhã" }
        if dias == 2 { return "Sai em 2 dias" }
        return "Próximo evento, em \(dias) dias"
    }

    private var tituloDisplay: String {
        guard vm.carregou else { return vm.isLoading ? "Um instante" : "Event Pro" }
        return vm.selecionado?.nome ?? "Nenhum evento na fila"
    }

    private var localDisplay: String {
        guard let evento = vm.selecionado else { return "" }
        if !evento.enderecoDisplayLine.isEmpty {
            return evento.enderecoDisplayLine
        }
        return evento.localDisplayName == evento.nome ? (evento.local ?? "") : evento.localDisplayName
    }

    private func diasAte(_ evento: Project) -> Int? {
        guard let data = evento.dataInicioDate else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day],
                                  from: cal.startOfDay(for: Date()),
                                  to: cal.startOfDay(for: data)).day
    }

    // MARK: Frase única de dados (sem rótulos; a distância NÃO fica aqui)

    @ViewBuilder
    private var frase: some View {
        if let evento = vm.selecionado {
            fraseTexto(evento)
        }
    }

    private func fraseTexto(_ evento: Project) -> Text {
        let data = dataCurta(evento)
        // Sem packing list ainda (total 0), a frase nao inventa "0 de 0":
        // fica so a data.
        guard let p = vm.prontidoes[evento.id], p.total > 0 else {
            return Text(data).font(EP.dados()).foregroundColor(EP.ink2)
        }
        return Text("\(data) · ").font(EP.dados()).foregroundColor(EP.ink2)
            + Text("\(p.prontos) de \(p.total)").font(EP.dadosForte().monospacedDigit()).foregroundColor(EP.ink)
            + Text(" itens prontos").font(EP.dados()).foregroundColor(EP.ink2)
    }

    // MARK: Agenda (ordem fixa; só muda quem está em destaque)

    private var agendaSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Agenda")
                    .font(EP.secao())
                    .foregroundStyle(EP.ink3)
                Spacer()
                Text(vm.agenda.count == 1 ? "1 evento" : "\(vm.agenda.count) eventos")
                    .font(EP.secao())
                    .foregroundStyle(EP.sub)
            }
            .padding(.horizontal, 12)
            .padding(.top, EP.s5)
            .padding(.bottom, 2)

            VStack(spacing: 0) {
                ForEach(Array(vm.agenda.enumerated()), id: \.element.id) { index, evento in
                    agendaRow(index, evento)
                }
            }
        }
    }

    private func agendaRow(_ index: Int, _ evento: Project) -> some View {
        let aberto = index == vm.selecionadoIndex
        // A hairline superior some na linha aberta e na seguinte.
        let mostraHairline = index > 0 && !aberto && index != vm.selecionadoIndex + 1
        return Button {
            vm.selecionar(index)
        } label: {
            HStack(spacing: 15) {
                Text(dataCurta(evento))
                    .font(EP.agendaData().monospacedDigit())
                    .foregroundStyle(EP.ink3)
                    .frame(width: 50, alignment: .leading)

                Text(evento.nome)
                    .font(nomeFont(evento, aberto: aberto))
                    .foregroundStyle(nomeCor(evento, aberto: aberto))
                    .lineLimit(1)

                Spacer(minLength: EP.s2)

                Text(evento.local ?? "")
                    .font(EP.agendaLocal())
                    .foregroundStyle(EP.sub)
                    .lineLimit(1)

                if aberto {
                    Image(systemName: "mappin")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(EP.ink2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 13)
            .frame(minHeight: EP.touchMin)
            // So o fundo anima (220ms, como no prototipo); texto e hairline
            // trocam secos. Animar a lista inteira deixava a troca pesada.
            .background {
                RoundedRectangle(cornerRadius: EP.r14, style: .continuous)
                    .fill(EP.paper2)
                    .opacity(aberto ? 1 : 0)
                    .animation(EP.linhaAgenda, value: aberto)
            }
            .overlay(alignment: .top) {
                if mostraHairline {
                    Rectangle().fill(EP.linha).frame(height: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Namespace proprio: topo e frase ja usam evento.id pro crossfade,
        // e o scrollTo acharia o primeiro (o topo) em vez da linha.
        .id("agenda-\(evento.id)")
        .accessibilityAddTraits(aberto ? .isSelected : [])
    }

    // Peso carrega o estado: planejamento (nao confirmado) e o unico leve.
    private func nomeFont(_ evento: Project, aberto: Bool) -> Font {
        if aberto { return EP.agendaNomeAberto() }
        return evento.status == .planejamento ? EP.agendaNomeSoft() : EP.agendaNome()
    }

    private func nomeCor(_ evento: Project, aberto: Bool) -> Color {
        if aberto { return EP.ink }
        return evento.status == .planejamento ? EP.ink2 : EP.ink
    }

    /// "11 ago", sem ponto e minúsculo, como no protótipo.
    private func dataCurta(_ evento: Project) -> String {
        guard let data = evento.dataInicioDate else { return "–" }
        return Self.dataFormatter.string(from: data)
            .replacingOccurrences(of: ".", with: "")
            .lowercased()
    }

    private static let dataFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "d MMM"
        return f
    }()

    // MARK: Erro (sem cor de alerta: peso e rótulo carregam o estado)

    private func errorNote(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Sem conexão com o servidor")
                .font(EP.dadosForte())
                .foregroundStyle(EP.ink)
            Text(message)
                .font(EP.secondary())
                .foregroundStyle(EP.sub)
                .lineLimit(2)
        }
        .padding(EP.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EP.paper2, in: RoundedRectangle(cornerRadius: EP.r14, style: .continuous))
    }
}

// MARK: - Abas ainda sem tela (empty state honesto, sem interação fake)

private struct AbaEmConstrucao: View {
    let icone: String
    let titulo: String
    let texto: String

    var body: some View {
        VStack(spacing: EP.s4) {
            Image(systemName: icone)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(EP.ink3)
                .frame(width: 56, height: 56)
                .background(EP.paper2, in: Circle())

            VStack(spacing: EP.s1) {
                Text(titulo)
                    .font(EP.itemTitle())
                    .foregroundStyle(EP.ink)
                Text(texto)
                    .font(EP.secondary())
                    .foregroundStyle(EP.sub)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, EP.s10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EP.paper)
    }
}

// MARK: - Ajustes (vive no avatar do topo; saiu da barra)

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthState

    var body: some View {
        VStack(alignment: .leading, spacing: EP.s6) {
            Text("Ajustes")
                .font(EP.screenTitle())
                .foregroundStyle(EP.ink)
                .padding(.top, EP.s6)

            VStack(alignment: .leading, spacing: EP.s2) {
                Text("Sessão")
                    .font(EP.secao())
                    .foregroundStyle(EP.ink3)
                Text(auth.email ?? "sem e-mail")
                    .font(EP.mono(14))
                    .foregroundStyle(EP.ink2)
            }
            .padding(EP.s5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EP.paper2, in: RoundedRectangle(cornerRadius: EP.r14, style: .continuous))

            Button {
                auth.signOut()
            } label: {
                Text("Sair")
                    .font(EP.itemTitle())
                    .foregroundStyle(EP.paper)
                    .frame(maxWidth: .infinity, minHeight: EP.touchMin + 4)
                    .background(EP.ink, in: RoundedRectangle(cornerRadius: EP.r12, style: .continuous))
            }
            .buttonStyle(EPPressStyle())

            Spacer()
        }
        .padding(.horizontal, EP.padTela)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(EP.paper)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
