import SwiftUI

// MARK: - StatusCounts
//
// Port do LiquidHomeViewModel do MMD: mesma agregacao, mesma semantica.
// "total" e operacional: exclui so vendido e baixa. "critico" (desgaste <= 2)
// e ortogonal aos contadores de status. A prontidao do hero NAO vem daqui:
// e calculada por evento (match de packing vs disponibilidade real).

struct StatusCounts {
    var disponivel = 0
    var emCampo = 0
    var manutencao = 0
    var critico = 0     // desgaste <= 2, dentro de operacao
    var semTag = 0      // sem tag_rfid, dentro de operacao
    var total = 0       // operacional (exclui vendido/baixa)

    static let zero = StatusCounts()
}

// MARK: - HomeViewModel
//
// Alimenta o cockpit com dado real do Supabase: proximo evento a despachar,
// prontidao desse evento e contadores do estoque.

@MainActor
final class HomeViewModel: ObservableObject {

    @Published private(set) var proximoEvento: Project?
    @Published private(set) var proximosEventos: [Project] = []
    @Published private(set) var counts = StatusCounts.zero
    @Published private(set) var prontidaoEvento: Double = 0
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var carregou = false

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            async let confirmados = apiClient.fetchProjects(status: [.confirmado])
            async let snapshot = apiClient.fetchSerialSnapshot()

            let (conf, snap) = try await (confirmados, snapshot)

            let proximo = pickProximo(conf)
            proximoEvento = proximo
            // Fila da agenda: os confirmados seguintes (a lista ja vem
            // ordenada por data_inicio.asc), sem repetir o hero.
            proximosEventos = Array(conf.filter { $0.id != proximo?.id }.prefix(3))
            counts = aggregate(snap)
            // Prontidao do EVENTO, nao do estoque: falha aqui nao derruba a
            // home, so zera o numero (estado honesto de "nada garantido").
            prontidaoEvento = (try? await prontidaoDoEvento(proximo)) ?? 0
            carregou = true
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Prontidao do evento
    //
    // Fracao da quantidade esperada do packing coberta por unidades
    // designadas que estao disponiveis AGORA (disponivel ou packed). Nada
    // designado = 0%: prontidao e garantia, nao esperanca.

    private func prontidaoDoEvento(_ evento: Project?) async throws -> Double {
        guard let evento else { return 0 }

        let packing = try await apiClient.fetchPackingList(projectId: evento.id)
        let totalEsperado = packing.reduce(0) { $0 + $1.quantidade }
        guard totalEsperado > 0 else { return 0 }

        let designados = Array(Set(packing.flatMap { $0.serialNumbersDesignados ?? [] }))
        guard !designados.isEmpty else { return 0 }

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
        return Double(prontos) / Double(totalEsperado)
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

    private func operacional(_ status: StatusSerial) -> Bool {
        status != .vendido && status != .baixa
    }

    private func aggregate(_ rows: [APIClient.SerialSnapshotRow]) -> StatusCounts {
        var c = StatusCounts()
        for r in rows {
            guard let status = r.status, operacional(status) else { continue }
            c.total += 1
            switch status {
            case .disponivel, .packed: c.disponivel += 1
            case .emCampo, .retornando: c.emCampo += 1
            case .manutencao: c.manutencao += 1
            default: break
            }
            if r.desgaste <= 2 { c.critico += 1 }
            if r.tagRfid?.isEmpty ?? true { c.semTag += 1 }
        }
        return c
    }
}
