import SwiftUI

// MARK: - StatusCounts
//
// Contadores agregados do estoque pra Home. "total" e operacional: exclui so
// vendido e baixa (fora de operacao). Emprestado conta no total (e na
// prontidao) de proposito: nao esta disponivel, entao derruba a prontidao, mas
// nao ganha contador proprio. "critico" (desgaste <= 2) e ortogonal aos
// contadores de status: atravessa disponivel/em campo/manutencao, nao soma com
// eles. "prontidao" e derivada (fracao disponivel) ate haver match real de
// packing vs disponibilidade.

struct StatusCounts {
    var disponivel = 0
    var emCampo = 0
    var manutencao = 0
    var critico = 0     // desgaste <= 2, dentro de operacao
    var semTag = 0      // sem tag_rfid, dentro de operacao
    var total = 0       // operacional (exclui vendido/baixa)

    static let zero = StatusCounts()

    /// Fracao do estoque pronta pra sair. Derivada (nao especifica de evento).
    var prontidao: Double {
        guard total > 0 else { return 0 }
        return Double(disponivel) / Double(total)
    }
}

// MARK: - LiquidHomeViewModel
//
// Alimenta a Home com dado real do Supabase: proximo evento a despachar e a
// prontidao do estoque (fracao disponivel) que abastece o ring do hero.

@MainActor
final class LiquidHomeViewModel: ObservableObject {

    @Published private(set) var proximoEvento: Project?
    @Published private(set) var counts = StatusCounts.zero
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var carregou = false

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let confirmados = apiClient.fetchProjects(status: [.confirmado])
            async let snapshot = apiClient.fetchSerialSnapshot()

            let (conf, snap) = try await (confirmados, snapshot)

            proximoEvento = pickProximo(conf)
            counts = aggregate(snap)
            carregou = true
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Derivacao

    /// Proximo evento a despachar: o confirmado mais cedo ainda por vir; se
    /// todos ja passaram (dado de seed), cai pro confirmado mais cedo. A lista
    /// chega ordenada por data_inicio.asc do fetch.
    private func pickProximo(_ confirmados: [Project]) -> Project? {
        let hoje = Calendar.current.startOfDay(for: Date())
        if let futuro = confirmados.first(where: { ($0.dataInicioDate ?? .distantPast) >= hoje }) {
            return futuro
        }
        // Todos ja passaram (ou sem data): prefere o mais cedo com data valida.
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
