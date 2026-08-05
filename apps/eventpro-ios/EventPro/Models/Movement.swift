import Foundation

// MARK: - TipoMovimentacao

enum TipoMovimentacao: String, Codable, CaseIterable, Identifiable {
    case saida = "SAIDA"
    case retorno = "RETORNO"
    case manutencao = "MANUTENCAO"
    case transferencia = "TRANSFERENCIA"
    case dano = "DANO"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .saida: return "Saida"
        case .retorno: return "Retorno"
        case .manutencao: return "Manutencao"
        case .transferencia: return "Transferencia"
        case .dano: return "Dano"
        }
    }
}

// MARK: - MetodoScan

enum MetodoScan: String, Codable, CaseIterable, Identifiable {
    case rfid = "RFID"
    case qrcode = "QRCODE"
    case manual = "MANUAL"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rfid: return "RFID"
        case .qrcode: return "QR Code"
        case .manual: return "Manual"
        }
    }
}

// MARK: - Contrato de check-out
//
// POST /api/eventos/{id}/checkout — docs/contratos-api.md seção 2.
// `overrideReason` é o único campo camelCase de toda a superfície (D6).
// Congelado: renomear quebra o app legado.

struct CheckoutProjectRequest: Encodable {
    let metodo: String
    let overrideReason: String?
}

struct CheckoutProjectResponse: Codable, Hashable {
    var count: Int
    var seriais: [CheckoutProjectSerial]
}

struct CheckoutProjectSerial: Codable, Hashable {
    var serialId: UUID
    var codigoInterno: String

    enum CodingKeys: String, CodingKey {
        case serialId = "serial_id"
        case codigoInterno = "codigo_interno"
    }
}

// MARK: - Contrato de retorno
//
// POST /api/eventos/{id}/retorno — docs/contratos-api.md seção 3.
// A RPC `checkin_projeto` exige cobertura total: a lista precisa ser
// exatamente o conjunto de seriais próprios EM_CAMPO do evento. Item não
// conferido vira NAO_VOLTOU explícito, nunca some do payload (divergência D1).

enum ReturnProjectOutcome: String, Codable, CaseIterable, Identifiable {
    case ok = "OK"
    case problema = "PROBLEMA"
    case naoVoltou = "NAO_VOLTOU"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ok: return "OK"
        case .problema: return "Problema"
        case .naoVoltou: return "Não voltou"
        }
    }

    /// Status de destino do serial, espelhando `returnDestination` do servidor.
    var novoStatus: StatusSerial {
        switch self {
        case .ok: return .disponivel
        case .problema: return .manutencao
        case .naoVoltou: return .retornando
        }
    }

    /// Só `NAO_VOLTOU` abre pendência em `retorno_pendencias`.
    var abrePendencia: Bool {
        self == .naoVoltou
    }
}

struct ReturnProjectItemRequest: Encodable, Equatable {
    let serialId: UUID
    let desgaste: Int
    let resultado: ReturnProjectOutcome
    let observacao: String?

    enum CodingKeys: String, CodingKey {
        case serialId = "serial_id"
        case desgaste
        case resultado
        case observacao
    }
}

struct ReturnProjectRequest: Encodable {
    let metodo: String
    let items: [ReturnProjectItemRequest]
}

struct ReturnProjectResponse: Codable, Hashable {
    var count: Int
    var seriais: [ReturnProjectSerial]
}

struct ReturnProjectSerial: Codable, Hashable {
    var serialId: UUID
    var codigoInterno: String
    var novoStatus: String

    enum CodingKeys: String, CodingKey {
        case serialId = "serial_id"
        case codigoInterno = "codigo_interno"
        case novoStatus = "novo_status"
    }
}

// MARK: - Contrato de scan RFID
//
// POST /api/rfid/scans — docs/contratos-api.md seção 5.

enum RfidScanContext: String, Codable, CaseIterable, Identifiable {
    case packing = "PACKING"
    case carregamento = "CARREGAMENTO"
    case checkInEvento = "CHECK_IN_EVENTO"
    case checkOutEvento = "CHECK_OUT_EVENTO"
    case retorno = "RETORNO"
    case conferencia = "CONFERENCIA"
    case inventario = "INVENTARIO"
    case outro = "OUTRO"

    var id: String { rawValue }
}

struct RfidScanReaderRequest: Encodable, Equatable {
    let nome: String?
    let modelo: String?
    let serialFabrica: String?
    let bateria: Int?

    enum CodingKeys: String, CodingKey {
        case nome
        case modelo
        case serialFabrica = "serial_fabrica"
        case bateria
    }
}

struct RfidScanRequest: Encodable {
    let tags: [String]
    let contexto: RfidScanContext
    let projetoId: UUID?
    let reader: RfidScanReaderRequest?

    /// `localizacao` existe na rota desde sempre e o app legado nunca enviava
    /// (divergência D7). Opcional: quando nil, o encoder omite e o corpo fica
    /// idêntico ao do legado.
    let localizacao: String?

    /// RSSI de pico por tag normalizada, em dBm. Campo **aditivo** previsto na
    /// política de mudança (seção 10, item 2) para fechar o gap de proximidade
    /// (D7). O parser congelado ignora chave desconhecida, então enviar isso
    /// contra um servidor antigo é inofensivo; quando nil, nem aparece no JSON.
    let rssiPorTag: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case tags
        case contexto
        case projetoId = "projeto_id"
        case reader
        case localizacao
        case rssiPorTag = "rssi_por_tag"
    }

    init(
        tags: [String],
        contexto: RfidScanContext,
        projetoId: UUID? = nil,
        reader: RfidScanReaderRequest? = nil,
        localizacao: String? = nil,
        rssiPorTag: [String: Int]? = nil
    ) {
        self.tags = tags
        self.contexto = contexto
        self.projetoId = projetoId
        self.reader = reader
        self.localizacao = localizacao
        self.rssiPorTag = (rssiPorTag?.isEmpty ?? true) ? nil : rssiPorTag
    }
}

struct RfidScanResponse: Codable, Hashable {
    var resolved: [RfidResolvedScan]
    var unresolved: [String]
    var scanIds: [UUID]

    enum CodingKeys: String, CodingKey {
        case resolved
        case unresolved
        case scanIds = "scan_ids"
    }
}

struct RfidResolvedScan: Codable, Hashable {
    var tagRfid: String
    var serialId: UUID
    var codigoInterno: String
    var itemNome: String?

    enum CodingKeys: String, CodingKey {
        case tagRfid = "tag_rfid"
        case serialId = "serial_id"
        case codigoInterno = "codigo_interno"
        case itemNome = "item_nome"
    }
}

// MARK: - Movement

/// Espelha a tabela `movimentacoes` do Supabase. Leitura apenas: toda escrita
/// operacional passa por RPC service-role-only atrás do BFF.
struct Movement: Identifiable, Codable, Hashable {
    let id: UUID
    var serialNumberId: UUID
    var projetoId: UUID? = nil
    var tipo: TipoMovimentacao
    var statusAnterior: String? = nil
    var statusNovo: String? = nil
    var registradoPor: String? = nil
    var metodoScan: MetodoScan? = nil
    var timestamp: Date? = nil
    var notas: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case serialNumberId = "serial_number_id"
        case projetoId = "projeto_id"
        case tipo
        case statusAnterior = "status_anterior"
        case statusNovo = "status_novo"
        case registradoPor = "registrado_por"
        case metodoScan = "metodo_scan"
        case timestamp
        case notas
    }
}
