import SwiftUI

// MARK: - Prontidao
//
// A frase de dados da Home fala "X de Y itens prontos", nao percentual:
// contagem de quantidade esperada do packing coberta por unidades designadas
// disponiveis agora. Nada designado = 0 de Y: prontidao e garantia, nao
// esperanca.

struct Prontidao: Equatable {
    var prontos = 0
    var total = 0
}

// MARK: - HomeViewModel
//
// Alimenta a aba Eventos (a tela do grill) com dado real do Supabase:
// todos os eventos cadastrados no horizonte operacional, evento destacado
// e prontidao por evento sob demanda. Nao confirmado e marcado por peso na
// UI; a selecao inicial e o proximo confirmado a despachar. Os KPIs de
// estoque sairam desta tela no redesenho 2.0.

@MainActor
final class HomeViewModel: ObservableObject {

    @Published private(set) var agenda: [Project] = []
    @Published private(set) var selecionadoIndex = 0
    @Published private(set) var prontidoes: [UUID: Prontidao] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var carregou = false
    @Published private(set) var canEditDestino = false

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var selecionado: Project? {
        guard agenda.indices.contains(selecionadoIndex) else { return nil }
        return agenda[selecionadoIndex]
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            // Todos os eventos ja cadastrados no horizonte operacional
            // (planejamento, confirmado, em campo), ordenados por
            // data_inicio.asc. Finalizado e cancelado sao historico e ficam
            // fora. A ordem e fixa e nunca se reorganiza, so muda quem esta
            // em destaque; o destaque inicial e o proximo confirmado.
            async let projects = apiClient.fetchProjects(
                status: [.planejamento, .confirmado, .emCampo]
            )
            async let role = apiClient.fetchMyRole()
            agenda = try await projects
            // Falha de role não derruba a agenda: default viewer (sem edição).
            canEditDestino = ((try? await role) ?? .viewer).canEditDestino
            let proximo = pickProximo(agenda.filter { $0.status == .confirmado })
            selecionadoIndex = agenda.firstIndex { $0.id == proximo?.id } ?? 0
            carregou = true
            await carregarProntidao(selecionado)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    /// Atualiza o pin na agenda local após gravação (ou restauração).
    func applyDestino(projectId: UUID, pin: DestinoPin?) {
        guard let index = agenda.firstIndex(where: { $0.id == projectId }) else { return }
        agenda[index].apply(pin: pin)
    }

    /// Troca o destaque (toque na agenda ou arrasto do carrossel), com wrap.
    /// A prontidao do evento novo carrega sob demanda e fica em cache.
    func selecionar(_ index: Int) {
        guard !agenda.isEmpty else { return }
        let n = agenda.count
        selecionadoIndex = ((index % n) + n) % n
        let evento = selecionado
        Task { await carregarProntidao(evento) }
    }

    // MARK: - Prontidao por evento

    private func carregarProntidao(_ evento: Project?) async {
        guard let evento, prontidoes[evento.id] == nil else { return }
        // Falha aqui nao derruba a home: sem resposta, a frase fica em
        // "0 de 0" honesto ate a proxima tentativa.
        let prontidao = (try? await prontidaoDoEvento(evento)) ?? Prontidao()
        prontidoes[evento.id] = prontidao
    }

    private func prontidaoDoEvento(_ evento: Project) async throws -> Prontidao {
        let packing = try await apiClient.fetchPackingList(projectId: evento.id)
        let totalEsperado = packing.reduce(0) { $0 + $1.quantidade }
        guard totalEsperado > 0 else { return Prontidao() }

        let designados = Array(Set(packing.flatMap { $0.serialNumbersDesignados ?? [] }))
        guard !designados.isEmpty else { return Prontidao(prontos: 0, total: totalEsperado) }

        let serials = try await apiClient.fetchSerialsByIds(designados)
        let statusPorId = Dictionary(serials.map { ($0.id, $0.status) },
                                     uniquingKeysWith: { first, _ in first })

        let prontos = packing.reduce(0) { acc, item in
            let ids = item.serialNumbersDesignados ?? []
            let disponiveis = ids.filter { id in
                let status = statusPorId[id]
                return status == .disponivel || status == .packed
            }.count
            return acc + min(disponiveis, item.quantidade)
        }
        return Prontidao(prontos: prontos, total: totalEsperado)
    }

    // MARK: - Derivacao

    /// Proximo evento a despachar: o confirmado mais cedo ainda por vir; se
    /// todos ja passaram (dado de seed), cai pro confirmado mais cedo.
    private func pickProximo(_ confirmados: [Project]) -> Project? {
        let hoje = Calendar.current.startOfDay(for: Date())
        if let futuro = confirmados.first(where: { ($0.dataInicioDate ?? .distantPast) >= hoje }) {
            return futuro
        }
        return confirmados.first { $0.dataInicioDate != nil } ?? confirmados.first
    }
}
