import SwiftUI

// MARK: - Status -> gramatica de badge
//
// Cor so com significado: estado operacional ganha badge de fundo cheio com
// texto escuro do chao. Planejamento e neutro de proposito: ainda nao e
// operacao, entao nao ganha cor de alerta, ganha superficie.

extension StatusProjeto {
    /// Cor do badge cheio. `nil` = badge neutro de superficie.
    var epBadgeFill: Color? {
        switch self {
        case .planejamento: return nil
        case .confirmado: return EP.stateInfo
        case .emCampo: return EP.stateField
        case .finalizado: return EP.stateReady
        case .cancelado: return EP.stateCritical
        }
    }
}

// MARK: - EventsListView
//
// Primeira tela real de operacao. A hierarquia dentro da lista e por peso e
// cor, nunca por tamanho: nome semibold fg0, subtitulo fg2, data em mono a
// direita. Quatro estados de dados: carregando, erro, vazio e com dados.

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
        ScrollView {
            VStack(alignment: .leading, spacing: EP.s6) {
                header
                content
            }
            .padding(.horizontal, EP.s5)
            .padding(.bottom, 96)
        }
        .background(EP.bg0)
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: Header (unico lugar da tela com escala grande)

    private var header: some View {
        VStack(alignment: .leading, spacing: EP.s1) {
            Text("Eventos")
                .font(EP.screenTitle())
                .foregroundStyle(EP.fg0)
            if phase == .loaded {
                Text(events.count == 1 ? "1 evento ativo" : "\(events.count) eventos ativos")
                    .font(EP.secondary())
                    .foregroundStyle(EP.fg2)
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
        VStack(alignment: .leading, spacing: EP.s2) {
            Text("ATIVOS")
                .font(EP.sectionLabel())
                .foregroundStyle(EP.fg2)
                .padding(.horizontal, EP.s1)

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
            .epSurface(1)
        }
    }

    /// Linha de dois andares: identidade a esquerda, tempo e estado a direita.
    private func row(_ event: Project) -> some View {
        HStack(alignment: .center, spacing: EP.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.nome)
                    .font(EP.itemTitle())
                    .foregroundStyle(EP.fg0)
                    .lineLimit(1)

                if let subtitle = subtitle(for: event) {
                    Text(subtitle)
                        .font(EP.secondary())
                        .foregroundStyle(EP.fg2)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: EP.s2)

            VStack(alignment: .trailing, spacing: EP.s1) {
                if let date = compactDate(for: event) {
                    Text(date)
                        .font(EP.mono(13))
                        .foregroundStyle(EP.fg1)
                }
                statusBadge(event.status)
            }
        }
        .padding(.horizontal, EP.s4)
        .padding(.vertical, EP.s2)
        .frame(minHeight: EP.rowHeightTall)
        .contentShape(Rectangle())
    }

    /// Badge de estado: fundo cheio com texto escuro do chao. O neutro
    /// (planejamento) e superficie com hairline, sem cor de alerta.
    private func statusBadge(_ status: StatusProjeto) -> some View {
        Text(status.displayName.uppercased())
            .font(EP.mono(10).weight(.medium))
            .tracking(0.5)
            .foregroundStyle(status.epBadgeFill == nil ? EP.fg1 : EP.bg0)
            .padding(.horizontal, EP.s2)
            .frame(height: 20)
            .background(status.epBadgeFill ?? EP.bg2, in: Capsule())
            .overlay {
                if status.epBadgeFill == nil {
                    Capsule().strokeBorder(EP.hairline, lineWidth: 1)
                }
            }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(EP.hairline)
            .frame(height: 1)
            .padding(.leading, EP.s4)
    }

    // MARK: Carregando

    private var skeleton: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                HStack(spacing: EP.s3) {
                    VStack(alignment: .leading, spacing: EP.s2) {
                        RoundedRectangle(cornerRadius: EP.r4).fill(EP.bg2)
                            .frame(width: 168, height: 12)
                        RoundedRectangle(cornerRadius: EP.r4).fill(EP.bg2)
                            .frame(width: 104, height: 10)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: EP.r4).fill(EP.bg2)
                        .frame(width: 56, height: 10)
                }
                .padding(.horizontal, EP.s4)
                .frame(height: EP.rowHeightTall)

                if index < 4 {
                    rowDivider
                }
            }
        }
        .epSurface(1)
        .accessibilityLabel("Carregando eventos")
    }

    // MARK: Vazio

    private var emptyState: some View {
        VStack(spacing: EP.s4) {
            Image(systemName: "calendar")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(EP.fg2)
                .frame(width: 56, height: 56)
                .epSurface(1, radius: EP.r16)

            VStack(spacing: EP.s1) {
                Text("Nenhum evento ativo")
                    .font(EP.itemTitle())
                    .foregroundStyle(EP.fg0)
                Text("Eventos em planejamento, confirmados ou em campo aparecem aqui.")
                    .font(EP.secondary())
                    .foregroundStyle(EP.fg2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, EP.s12)
    }

    // MARK: Erro

    private func errorState(_ message: String) -> some View {
        VStack(spacing: EP.s4) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(EP.stateCritical)
                .frame(width: 56, height: 56)
                .epSurface(1, radius: EP.r16)

            VStack(spacing: EP.s1) {
                Text("Falha ao carregar")
                    .font(EP.itemTitle())
                    .foregroundStyle(EP.fg0)
                Text(message)
                    .font(EP.secondary())
                    .foregroundStyle(EP.fg2)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await load() }
            } label: {
                Text("Tentar de novo")
                    .font(EP.itemTitle())
                    .foregroundStyle(EP.fg1)
                    .frame(maxWidth: .infinity, minHeight: EP.touchMin)
                    .epSurface(2, radius: EP.r10)
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
