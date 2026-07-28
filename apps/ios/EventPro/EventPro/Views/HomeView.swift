import SwiftUI

/// Raiz autenticada: troca de aba real na barra flutuante. O Início e o
/// cockpit do MMD reembalado na gramática EP e abre por padrão.
struct HomeView: View {
    @State private var tab: Tab = .inicio

    enum Tab: Int {
        case inicio, eventos, ajustes
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .inicio: InicioView()
                case .eventos: EventsListView()
                case .ajustes: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingBar(active: $tab)
        }
        .background(EP.bg0)
    }
}

// MARK: - InicioView
//
// Cockpit operacional do MMD (LiquidHome) reembalado: hero do proximo evento
// com prontidao como numero heroi, regua de KPIs do estoque, agenda dos
// proximos confirmados e pendencia de atencao. Mesmos dados, mesma logica
// (HomeViewModel e port do LiquidHomeViewModel); muda so a lei visual.
// Sem scroll: tudo cabe na tela, como no MMD. Sem interacao fake: hero e
// agenda viram botao quando os destinos existirem no Event Pro.

struct InicioView: View {
    @EnvironmentObject private var api: APIClient

    var body: some View {
        InicioContent(apiClient: api)
    }
}

private struct InicioContent: View {

    @StateObject private var vm: HomeViewModel

    init(apiClient: APIClient) {
        _vm = StateObject(wrappedValue: HomeViewModel(apiClient: apiClient))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EP.s5) {
            heroCard

            kpiCard

            if let erro = vm.errorMessage {
                errorNote(erro)
            }

            if !vm.proximosEventos.isEmpty {
                agendaSection
            }

            if vm.carregou, vm.counts.semTag > 0 {
                atencaoSection
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, EP.s5)
        .padding(.top, EP.s4)
        .padding(.bottom, 96)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(EP.bg0)
        .task { if !vm.carregou { await vm.load() } }
    }

    // MARK: Hero
    //
    // O unico lugar da tela com escala grande: o numero heroi de prontidao.
    // Identidade do evento por peso e cor, como dentro de lista.

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: EP.s4) {
            Text("PRÓXIMO EVENTO")
                .font(EP.sectionLabel())
                .foregroundStyle(EP.fg2)

            if let evento = vm.proximoEvento {
                HStack(alignment: .center, spacing: EP.s4) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(evento.nome)
                            .font(EP.itemTitle())
                            .foregroundStyle(EP.fg0)
                            .lineLimit(2)
                        if let cliente = evento.cliente {
                            Text(cliente)
                                .font(EP.secondary())
                                .foregroundStyle(EP.fg2)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: EP.s3)

                    VStack(alignment: .trailing, spacing: 0) {
                        Text(prontidaoLabel)
                            .font(EP.heroNumber())
                            .foregroundStyle(prontidaoColor)
                        Text("PRONTIDÃO")
                            .font(EP.sectionLabel())
                            .foregroundStyle(EP.fg2)
                    }
                }

                Rectangle()
                    .fill(EP.hairline)
                    .frame(height: 1)

                HStack(spacing: EP.s4) {
                    if let data = evento.dataInicioFormatado {
                        Label(data, systemImage: "calendar")
                            .font(EP.mono(11))
                            .foregroundStyle(EP.fg1)
                            .lineLimit(1)
                            .layoutPriority(1)
                    }
                    if let local = evento.local {
                        Label(local, systemImage: "mappin.and.ellipse")
                            .font(EP.mono(11))
                            .foregroundStyle(EP.fg2)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: EP.s3) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(EP.fg2)
                        .frame(width: EP.s11, height: EP.s11)
                        .background(EP.bg2, in: RoundedRectangle(cornerRadius: EP.r10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.isLoading ? "Buscando eventos" : "Nenhum evento na fila")
                            .font(EP.itemTitle())
                            .foregroundStyle(EP.fg0)
                        Text(vm.isLoading ? "Um instante" : "Eventos confirmados aparecem aqui pra despacho")
                            .font(EP.secondary())
                            .foregroundStyle(EP.fg2)
                    }
                }
            }
        }
        .padding(EP.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .epSurface(1, radius: EP.r16)
    }

    private var prontidaoLabel: String {
        guard vm.carregou else { return "–" }
        return "\(Int((vm.prontidaoEvento * 100).rounded()))%"
    }

    /// Cor com significado: garantido e verde, parcial e atencao, nada
    /// designado e critico. Sem dado ainda, sem cor.
    private var prontidaoColor: Color {
        guard vm.carregou else { return EP.fg3 }
        if vm.prontidaoEvento >= 1 { return EP.stateReady }
        if vm.prontidaoEvento > 0 { return EP.stateField }
        return EP.stateCritical
    }

    // MARK: KPIs do estoque

    private var kpiCard: some View {
        HStack(spacing: 0) {
            kpiStat(vm.carregou ? vm.counts.disponivel : nil, "disponível", EP.stateReady)
            kpiDivider
            kpiStat(vm.carregou ? vm.counts.emCampo : nil, "em campo", EP.stateField)
            kpiDivider
            kpiStat(vm.carregou ? vm.counts.manutencao : nil, "manutenção", EP.stateCritical)
        }
        .padding(.horizontal, EP.s5)
        .padding(.vertical, EP.s4)
        .frame(maxWidth: .infinity)
        .epSurface(1)
    }

    private var kpiDivider: some View {
        Rectangle()
            .fill(EP.hairline)
            .frame(width: 1, height: EP.s7)
            .padding(.trailing, EP.s4)
    }

    /// Milhar no formato brasileiro: 1.049, nunca 1049.
    static func formatted(_ value: Int) -> String {
        Self.milharFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let milharFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "pt_BR")
        return f
    }()

    private func kpiStat(_ value: Int?, _ label: String, _ dot: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value.map(Self.formatted) ?? "–")
                .font(EP.mono(18).weight(.medium))
                .foregroundStyle(value == nil ? EP.fg3 : EP.fg0)

            HStack(spacing: EP.s1) {
                Circle()
                    .fill((value ?? 0) > 0 ? dot : EP.fg3)
                    .frame(width: 5, height: 5)
                Text(label)
                    .font(EP.secondary())
                    .foregroundStyle(EP.fg2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value.map(String.init) ?? "sem dado") \(label)")
    }

    // MARK: Erro

    private func errorNote(_ message: String) -> some View {
        HStack(alignment: .top, spacing: EP.s3) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(EP.stateField)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sem conexão com o servidor")
                    .font(EP.body())
                    .foregroundStyle(EP.fg1)
                Text(message)
                    .font(EP.secondary())
                    .foregroundStyle(EP.fg3)
                    .lineLimit(1)
            }
        }
        .padding(EP.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .epSurface(1)
    }

    // MARK: Agenda

    private var agendaSection: some View {
        VStack(alignment: .leading, spacing: EP.s2) {
            Text("AGENDA")
                .font(EP.sectionLabel())
                .foregroundStyle(EP.fg2)
                .padding(.horizontal, EP.s1)

            VStack(spacing: 0) {
                ForEach(Array(vm.proximosEventos.enumerated()), id: \.element.id) { index, evento in
                    agendaRow(evento)
                    if index < vm.proximosEventos.count - 1 {
                        Rectangle()
                            .fill(EP.hairline)
                            .frame(height: 1)
                            .padding(.leading, EP.s4)
                    }
                }
            }
            .epSurface(1)
        }
    }

    private func agendaRow(_ evento: Project) -> some View {
        HStack(spacing: EP.s3) {
            dateBlock(evento)

            VStack(alignment: .leading, spacing: 1) {
                Text(evento.nome)
                    .font(EP.itemTitle())
                    .foregroundStyle(EP.fg0)
                    .lineLimit(1)
                if let sub = evento.cliente ?? evento.local {
                    Text(sub)
                        .font(EP.secondary())
                        .foregroundStyle(EP.fg2)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: EP.s2)
        }
        .padding(.horizontal, EP.s4)
        .padding(.vertical, EP.s2)
        .frame(minHeight: EP.rowHeightTall)
    }

    /// Dia (mono) sobre mes abreviado, num chip: calendario de instrumento.
    private func dateBlock(_ evento: Project) -> some View {
        VStack(spacing: 0) {
            Text(evento.dataInicioDate.map { Self.diaFormatter.string(from: $0) } ?? "–")
                .font(EP.mono(15).weight(.medium))
                .foregroundStyle(EP.fg0)
            Text(evento.dataInicioDate.map { Self.mesFormatter.string(from: $0).uppercased() } ?? "")
                .font(.custom("InterTight", size: 9).weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(EP.fg2)
        }
        .frame(width: EP.s10, height: EP.s10)
        .background(EP.bg2, in: RoundedRectangle(cornerRadius: EP.r10, style: .continuous))
    }

    private static let diaFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "d"
        return f
    }()

    private static let mesFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "MMM"
        return f
    }()

    // MARK: Atencao
    //
    // Pendencia real do estoque: itens sem tag. Vira botao quando a trilha
    // Etiquetar existir no Event Pro.

    private var atencaoSection: some View {
        VStack(alignment: .leading, spacing: EP.s2) {
            Text("ATENÇÃO")
                .font(EP.sectionLabel())
                .foregroundStyle(EP.fg2)
                .padding(.horizontal, EP.s1)

            HStack(spacing: EP.s3) {
                Image(systemName: "tag")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(EP.fg0)
                    .frame(width: EP.s9, height: EP.s9)
                    .background(EP.bg2, in: RoundedRectangle(cornerRadius: EP.r10, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Itens sem tag")
                        .font(EP.itemTitle())
                        .foregroundStyle(EP.fg0)
                    Text("Etiquetar pra rastrear")
                        .font(EP.secondary())
                        .foregroundStyle(EP.fg2)
                }

                Spacer(minLength: EP.s2)

                HStack(spacing: EP.s1) {
                    Circle().fill(EP.stateField).frame(width: 5, height: 5)
                    Text(InicioContent.formatted(vm.counts.semTag))
                        .font(EP.mono(11).weight(.medium))
                        .foregroundStyle(EP.fg1)
                }
                .padding(.horizontal, EP.s2)
                .padding(.vertical, 4)
                .background(EP.bg2, in: Capsule())
            }
            .padding(.horizontal, EP.s4)
            .padding(.vertical, EP.s2)
            .frame(maxWidth: .infinity, minHeight: EP.rowHeightTall, alignment: .leading)
            .epSurface(1)
        }
    }
}

/// Ajustes: sessao ativa e saida.
struct SettingsView: View {
    @EnvironmentObject private var auth: AuthState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EP.s6) {
                VStack(alignment: .leading, spacing: EP.s1) {
                    Text("Ajustes")
                        .font(EP.screenTitle())
                        .foregroundStyle(EP.fg0)
                }
                .padding(.top, EP.s4)

                VStack(alignment: .leading, spacing: EP.s2) {
                    Text("SESSÃO")
                        .font(EP.sectionLabel())
                        .foregroundStyle(EP.fg2)
                    Text(auth.email ?? "sem e-mail")
                        .font(EP.mono(14))
                        .foregroundStyle(EP.fg1)
                }
                .padding(EP.s5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .epSurface(1)

                Button {
                    auth.signOut()
                } label: {
                    Text("Sair")
                        .font(EP.itemTitle())
                        .foregroundStyle(EP.fg1)
                        .frame(maxWidth: .infinity, minHeight: EP.touchMin)
                        .epSurface(2, radius: EP.r10)
                }
                .buttonStyle(EPPressStyle())
            }
            .padding(.horizontal, EP.s5)
            .padding(.bottom, 96)
        }
        .background(EP.bg0)
    }
}

/// Barra flutuante: pilula que se separa por forma e hairline, nao por cor.
/// Item ativo marcado por halo tonal de baixa saturacao.
struct FloatingBar: View {
    @Binding var active: HomeView.Tab

    private let items: [(tab: HomeView.Tab, icon: String, label: String)] = [
        (.inicio, "house.fill", "Início"),
        (.eventos, "calendar", "Eventos"),
        (.ajustes, "gearshape", "Ajustes"),
    ]

    var body: some View {
        HStack(spacing: EP.s3) {
            HStack(spacing: 0) {
                ForEach(items, id: \.tab) { item in
                    Button {
                        withAnimation(EP.snappy) { active = item.tab }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: item.icon)
                                .font(.system(size: 17, weight: .medium))
                            Text(item.label)
                                .font(EP.secondary())
                        }
                        .foregroundStyle(active == item.tab ? EP.fg0 : EP.fg2)
                        .frame(maxWidth: .infinity, minHeight: EP.touchMin + 8)
                        .background {
                            if active == item.tab {
                                RoundedRectangle(cornerRadius: EP.r16, style: .continuous)
                                    .fill(EP.selectionHalo(EP.stateInfo))
                                    .matchedGeometryEffect(id: "bar-halo", in: halo)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(EP.s1)
            .epSurface(3, radius: EP.r20 + 8)

            Button {
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(EP.bg0)
                    .frame(width: EP.touchMin + 12, height: EP.touchMin + 12)
                    .background(EP.stateInfo, in: Circle())
            }
            .buttonStyle(EPPressStyle())
        }
        .padding(.horizontal, EP.s5)
        .padding(.bottom, EP.s2)
    }

    @Namespace private var halo
}
