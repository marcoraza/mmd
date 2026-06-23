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

// MARK: - HomeAlert
//
// Item acionavel da fila "precisa da sua atencao". Cada alerta empurra a tela
// que resolve o problema. So entra aqui o que tem destino claro e nao e mero
// contador (esses ficam na linha de status).

struct HomeAlert: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let detail: String
    let route: AppRoute
}

// MARK: - LiquidHomeViewModel
//
// Alimenta o cockpit da Home com dado real do Supabase: proximo evento a
// despachar, contadores de status do estoque e a fila de atencao derivada.

@MainActor
final class LiquidHomeViewModel: ObservableObject {

    @Published private(set) var proximoEvento: Project?
    @Published private(set) var counts = StatusCounts.zero
    @Published private(set) var alertas: [HomeAlert] = []
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
            async let emCampo = apiClient.fetchProjects(status: [.emCampo])
            async let snapshot = apiClient.fetchSerialSnapshot()

            let (conf, campo, snap) = try await (confirmados, emCampo, snapshot)

            proximoEvento = pickProximo(conf)
            counts = aggregate(snap)
            alertas = buildAlertas(snapshot: snap, emCampo: campo)
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

    private func buildAlertas(snapshot rows: [APIClient.SerialSnapshotRow], emCampo projetos: [Project]) -> [HomeAlert] {
        var out: [HomeAlert] = []

        let semTag = rows.filter {
            guard let s = $0.status, operacional(s) else { return false }
            return $0.tagRfid?.isEmpty ?? true
        }.count
        if semTag > 0 {
            out.append(HomeAlert(
                icon: "tag.slash",
                color: Liquid.accentViolet,
                title: "\(semTag) \(semTag == 1 ? "item sem tag" : "itens sem tag") RFID",
                detail: "Vincular pra rastrear",
                route: .etiquetar(tag: nil)
            ))
        }

        let hoje = Calendar.current.startOfDay(for: Date())
        let vencidos = projetos.filter { ($0.dataFimDate ?? .distantFuture) < hoje }.count
        if vencidos > 0 {
            out.append(HomeAlert(
                icon: "clock.badge.exclamationmark",
                color: Liquid.accentAmber,
                title: "\(vencidos) \(vencidos == 1 ? "projeto vencido" : "projetos vencidos") em campo",
                detail: "Confirmar a volta do campo",
                route: .projetos(.emCampo)
            ))
        }

        return out
    }
}
