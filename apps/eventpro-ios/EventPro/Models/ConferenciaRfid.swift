import Foundation

// MARK: - Contexto de conferência

/// Contextos aceitos por `POST /api/eventos/{id}/conferencia-rfid`.
///
/// Diferente de `/api/rfid/scans`, aqui contexto ausente ou fora da lista é
/// erro (`contexto_invalido`), não default silencioso (divergência D8).
enum ConferenciaContexto: String, Codable, CaseIterable, Identifiable {
    case carregamento = "CARREGAMENTO"
    case retorno = "RETORNO"
    case conferencia = "CONFERENCIA"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .carregamento: return "Carregamento"
        case .retorno: return "Retorno"
        case .conferencia: return "Conferência"
        }
    }

    /// Contexto equivalente na telemetria de `/api/rfid/scans`.
    var scanContext: RfidScanContext {
        switch self {
        case .carregamento: return .carregamento
        case .retorno: return .retorno
        case .conferencia: return .conferencia
        }
    }
}

// MARK: - Request

/// Corpo de `POST /api/eventos/{id}/conferencia-rfid` — contratos-api.md § 7.2.
struct ConferenciaRfidRequest: Encodable {
    let tags: [String]
    let contexto: ConferenciaContexto
    let reader: RfidScanReaderRequest?
    let localizacao: String?

    init(
        tags: [String],
        contexto: ConferenciaContexto,
        reader: RfidScanReaderRequest? = nil,
        localizacao: String? = nil
    ) {
        self.tags = tags
        self.contexto = contexto
        self.reader = reader
        self.localizacao = localizacao
    }
}

// MARK: - Response

/// Resposta de `POST /api/eventos/{id}/conferencia-rfid` — contratos-api.md § 7.4.
///
/// Só `confirmados`, `faltantes`, `extras` e `desconhecidas` são obrigatórios no
/// contrato. `evento`, `contexto`, `resumo` e `scan_ids` são aditivos e por isso
/// entram como opcionais aqui: servidor que não os mande não quebra o decode.
struct ConferenciaRfidResponse: Codable, Hashable {
    var confirmados: [ConferenciaSerial]
    var faltantes: [ConferenciaSerial]
    var extras: [ConferenciaSerial]
    var desconhecidas: [String]

    var evento: ConferenciaEvento?
    var contexto: ConferenciaContexto?
    var resumo: ConferenciaResumo?
    var scanIds: [UUID]?

    enum CodingKeys: String, CodingKey {
        case confirmados
        case faltantes
        case extras
        case desconhecidas
        case evento
        case contexto
        case resumo
        case scanIds = "scan_ids"
    }

    /// Resumo do servidor quando vier; senão, recalculado dos buckets.
    var resumoEfetivo: ConferenciaResumo {
        if let resumo { return resumo }
        return ConferenciaResumo(
            esperados: confirmados.count + faltantes.count,
            confirmados: confirmados.count,
            faltantes: faltantes.count,
            extras: extras.count,
            desconhecidas: desconhecidas.count,
            coberturaPct: Self.cobertura(
                confirmados: confirmados.count,
                esperados: confirmados.count + faltantes.count
            )
        )
    }

    static func cobertura(confirmados: Int, esperados: Int) -> Int {
        guard esperados > 0 else { return 0 }
        return Int((Double(confirmados) / Double(esperados) * 100).rounded())
    }
}

struct ConferenciaEvento: Codable, Hashable {
    var id: UUID
    var nome: String
    var status: StatusProjeto
}

struct ConferenciaSerial: Codable, Hashable, Identifiable {
    var serialId: UUID
    var codigoInterno: String
    var itemNome: String?

    /// Em `confirmados` e `extras`, a tag normalizada que foi lida.
    /// Em `faltantes`, a tag cadastrada no serial — **null quando o serial não
    /// tem tag vinculada**, que é exatamente o caso a destacar na UI.
    var tagRfid: String?

    var id: UUID { serialId }

    /// Faltante sem tag: não dá para achar por RFID, precisa de vínculo antes.
    var semTagVinculada: Bool {
        tagRfid == nil
    }

    enum CodingKeys: String, CodingKey {
        case serialId = "serial_id"
        case codigoInterno = "codigo_interno"
        case itemNome = "item_nome"
        case tagRfid = "tag_rfid"
    }
}

struct ConferenciaResumo: Codable, Hashable {
    var esperados: Int
    var confirmados: Int
    var faltantes: Int
    var extras: Int
    var desconhecidas: Int
    var coberturaPct: Int

    enum CodingKeys: String, CodingKey {
        case esperados
        case confirmados
        case faltantes
        case extras
        case desconhecidas
        case coberturaPct = "cobertura_pct"
    }

    var coberturaFraction: Double {
        Double(max(0, min(100, coberturaPct))) / 100.0
    }
}
