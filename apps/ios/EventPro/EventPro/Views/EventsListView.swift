import SwiftUI

// MARK: - EventsListView
//
// Lista de eventos na lei clara: linhas sobre o papel separadas por
// hairline, hierarquia por peso e cor, nunca por tamanho. Estado do evento
// sem cor de acento: rótulo com peso (em campo pesa mais que planejamento).
// Quatro estados de dados: carregando, erro, vazio e com dados.

struct EventsListView: View {

    var onSelect: (Project) -> Void = { _ in }

    @EnvironmentObject private var api: APIClient

    @State private var events: [Project] = []
    @State private var phase: Phase = .loading

    enum Phase: Equatable {
        case loading
        case error(String)
        case loaded
    }

    /// Horizonte operacional: o que ainda vai acontecer ou esta acontecendo.
    /// Finalizado e cancelado sao historico e entram em outra tela.
    private static let activeStatuses: [StatusProjeto] = [.planejamento, .confirmado, .emCampo]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: EP.s6) {
                header
                content
            }
            .padding(.horizontal, EP.padTela)
            .padding(.bottom, EP.padBarra)
        }
        .background(EP.paper)
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: Header (unico lugar da tela com escala grande)

    private var header: some View {
        VStack(alignment: .leading, spacing: EP.s1) {
            Text("Eventos")
                .font(EP.screenTitle())
                .foregroundStyle(EP.ink)
            if phase == .loaded {
                Text(events.count == 1 ? "1 evento ativo" : "\(events.count) eventos ativos")
                    .font(EP.secondary())
                    .foregroundStyle(EP.sub)
            }
        }
        .padding(.top, EP.s4)
    }

    // MARK: Estados de dados

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            skeleton
        case .error(let message):
            errorState(message)
        case .loaded:
            if events.isEmpty {
                emptyState
            } else {
                eventList
            }
        }
    }

    // MARK: Lista

    private var eventList: some View {
        VStack(spacing: 0) {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                Button {
                    onSelect(event)
                } label: {
                    row(event)
                }
                .buttonStyle(EPPressStyle())

                if index < events.count - 1 {
                    rowDivider
                }
            }
        }
    }

    /// Linha de dois andares: identidade a esquerda, tempo e estado a direita.
    private func row(_ event: Project) -> some View {
        HStack(alignment: .center, spacing: EP.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.nome)
                    .font(EP.itemTitle())
                    .foregroundStyle(EP.ink)
                    .lineLimit(1)

                if let subtitle = subtitle(for: event) {
                    Text(subtitle)
                        .font(EP.secondary())
                        .foregroundStyle(EP.sub)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: EP.s2)

            VStack(alignment: .trailing, spacing: EP.s1) {
                if let date = compactDate(for: event) {
                    Text(date)
                        .font(EP.mono(13))
                        .foregroundStyle(EP.ink2)
                }
                statusLabel(event.status)
            }
        }
        .padding(.vertical, EP.s2)
        .frame(minHeight: EP.rowHeightTall)
        .contentShape(Rectangle())
    }

    /// Estado sem cor: rótulo com peso. Em campo é operação viva e pesa
    /// mais; planejamento é o mais leve.
    private func statusLabel(_ status: StatusProjeto) -> some View {
        Text(status.displayName)
            .font(status == .emCampo ? EP.secao() : EP.secondary())
            .foregroundStyle(status == .emCampo ? EP.ink : (status == .confirmado ? EP.ink2 : EP.sub))
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(EP.linha)
            .frame(height: 1)
    }

    // MARK: Carregando

    private var skeleton: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                HStack(spacing: EP.s3) {
                    VStack(alignment: .leading, spacing: EP.s2) {
                        RoundedRectangle(cornerRadius: EP.r4).fill(EP.paper2)
                            .frame(width: 168, height: 12)
                        RoundedRectangle(cornerRadius: EP.r4).fill(EP.paper2)
                            .frame(width: 104, height: 10)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: EP.r4).fill(EP.paper2)
                        .frame(width: 56, height: 10)
                }
                .frame(height: EP.rowHeightTall)

                if index < 4 {
                    rowDivider
                }
            }
        }
        .accessibilityLabel("Carregando eventos")
    }

    // MARK: Vazio

    private var emptyState: some View {
        VStack(spacing: EP.s4) {
            Image(systemName: "calendar")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(EP.ink3)
                .frame(width: 56, height: 56)
                .background(EP.paper2, in: Circle())

            VStack(spacing: EP.s1) {
                Text("Nenhum evento ativo")
                    .font(EP.itemTitle())
                    .foregroundStyle(EP.ink)
                Text("Eventos em planejamento, confirmados ou em campo aparecem aqui.")
                    .font(EP.secondary())
                    .foregroundStyle(EP.sub)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, EP.s12)
    }

    // MARK: Erro

    private func errorState(_ message: String) -> some View {
        VStack(spacing: EP.s4) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(EP.ink3)
                .frame(width: 56, height: 56)
                .background(EP.paper2, in: Circle())

            VStack(spacing: EP.s1) {
                Text("Falha ao carregar")
                    .font(EP.itemTitle())
                    .foregroundStyle(EP.ink)
                Text(message)
                    .font(EP.secondary())
                    .foregroundStyle(EP.sub)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await load() }
            } label: {
                Text("Tentar de novo")
                    .font(EP.itemTitle())
                    .foregroundStyle(EP.paper)
                    .frame(maxWidth: .infinity, minHeight: EP.touchMin)
                    .background(EP.ink, in: RoundedRectangle(cornerRadius: EP.r12, style: .continuous))
            }
            .buttonStyle(EPPressStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, EP.s8)
    }

    // MARK: Dados

    private func load() async {
        if events.isEmpty { phase = .loading }
        do {
            events = try await api.fetchProjects(status: Self.activeStatuses)
            phase = .loaded
        } catch {
            // Refresh com dados na tela nao derruba a lista por erro passageiro.
            if events.isEmpty {
                phase = .error(error.localizedDescription)
            }
        }
    }

    // MARK: Formatacao

    private func subtitle(for event: Project) -> String? {
        let parts = [event.cliente, event.local].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "27 jul" quando tem data; ano so quando nao e o ano corrente.
    private static let compactFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM"
        f.locale = Locale(identifier: "pt_BR")
        return f
    }()

    private static let compactYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yy"
        f.locale = Locale(identifier: "pt_BR")
        return f
    }()

    private func compactDate(for event: Project) -> String? {
        guard let date = event.dataInicioDate else { return nil }
        let sameYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        let formatter = sameYear ? Self.compactFormatter : Self.compactYearFormatter
        return formatter.string(from: date)
    }
}
