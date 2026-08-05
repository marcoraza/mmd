import Foundation

// MARK: - EventoResumo

/// Resposta de `GET /api/eventos/{id}/resumo` — docs/contratos-api.md seção 4.
///
/// O app legado nunca chamava esse endpoint: agregava tudo client-side por
/// PostgREST (`fetchProjects` + `fetchPackingList` + `fetchSerialSnapshot`
/// paginado). O EventPro consome o resumo.
struct EventoResumo: Codable, Identifiable, Hashable {
    let id: UUID
    var nome: String
    var cliente: String?
    var dataInicio: String?
    var dataFim: String?
    var local: String?
    var status: StatusProjeto
    var notas: String?
    var packing: EventoResumoPacking

    enum CodingKeys: String, CodingKey {
        case id
        case nome
        case cliente
        case dataInicio = "data_inicio"
        case dataFim = "data_fim"
        case local
        case status
        case notas
        case packing
        // `ficha_evento` é jsonb versionado no servidor. O app não lê ficha
        // hoje (ela nasce e vive no web), então a chave é ignorada de propósito
        // em vez de virar um tipo frouxo aqui.
    }

    /// Projeção do resumo no `Project` que o resto do app já fala.
    var asProject: Project {
        Project(
            id: id,
            nome: nome,
            cliente: cliente,
            dataInicio: dataInicio,
            dataFim: dataFim,
            local: local,
            status: status,
            notas: notas
        )
    }
}

struct EventoResumoPacking: Codable, Hashable {
    var linhas: Int
    var itensTotal: Int
    var itensAlocados: Int
    var readinessPct: Int

    enum CodingKeys: String, CodingKey {
        case linhas
        case itensTotal = "itens_total"
        case itensAlocados = "itens_alocados"
        case readinessPct = "readiness_pct"
    }

    /// 0.0 a 1.0, para barras de progresso.
    var readinessFraction: Double {
        Double(max(0, min(100, readinessPct))) / 100.0
    }
}
