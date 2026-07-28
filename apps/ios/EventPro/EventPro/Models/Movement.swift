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

// MARK: - Shared Checkout API Contract

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

// MARK: - Shared Return API Contract

enum ReturnProjectOutcome: String, Codable, CaseIterable, Identifiable {
    case ok = "OK"
    case problema = "PROBLEMA"
    case naoVoltou = "NAO_VOLTOU"

    var id: String { rawValue }
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

// MARK: - Shared RFID Scan API Contract

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

    enum CodingKeys: String, CodingKey {
        case tags
        case contexto
        case projetoId = "projeto_id"
        case reader
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

/// Maps to the Supabase "movimentacoes" table.
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

// MARK: - CheckoutMovementRequest

/// Encodable struct for batch POST to /rest/v1/movimentacoes during checkout.
struct CheckoutMovementRequest: Encodable {
    let serialNumberId: UUID
    let projetoId: UUID
    let tipo: String
    let statusAnterior: String
    let statusNovo: String
    let registradoPor: String?
    let metodoScan: String
    let notas: String?

    enum CodingKeys: String, CodingKey {
        case serialNumberId = "serial_number_id"
        case projetoId = "projeto_id"
        case tipo
        case statusAnterior = "status_anterior"
        case statusNovo = "status_novo"
        case registradoPor = "registrado_por"
        case metodoScan = "metodo_scan"
        case notas
    }

    init(
        serialNumberId: UUID,
        projetoId: UUID,
        statusAnterior: String,
        registradoPor: String? = nil,
        metodoScan: String,
        notas: String? = nil
    ) {
        self.serialNumberId = serialNumberId
        self.projetoId = projetoId
        self.tipo = TipoMovimentacao.saida.rawValue
        self.statusAnterior = statusAnterior
        self.statusNovo = StatusSerial.emCampo.rawValue
        self.registradoPor = registradoPor
        self.metodoScan = metodoScan
        self.notas = notas
    }
}

// MARK: - ReturnMovementRequest

/// Encodable struct for batch POST to /rest/v1/movimentacoes during return.
struct ReturnMovementRequest: Encodable {
    let serialNumberId: UUID
    let projetoId: UUID
    let tipo: String
    let statusAnterior: String
    let statusNovo: String
    let registradoPor: String?
    let metodoScan: String
    let notas: String?

    enum CodingKeys: String, CodingKey {
        case serialNumberId = "serial_number_id"
        case projetoId = "projeto_id"
        case tipo
        case statusAnterior = "status_anterior"
        case statusNovo = "status_novo"
        case registradoPor = "registrado_por"
        case metodoScan = "metodo_scan"
        case notas
    }

    init(
        serialNumberId: UUID,
        projetoId: UUID,
        tipo: TipoMovimentacao,
        statusNovo: String,
        registradoPor: String? = nil,
        metodoScan: String,
        notas: String? = nil
    ) {
        self.serialNumberId = serialNumberId
        self.projetoId = projetoId
        self.tipo = tipo.rawValue
        self.statusAnterior = StatusSerial.emCampo.rawValue
        self.statusNovo = statusNovo
        self.registradoPor = registradoPor
        self.metodoScan = metodoScan
        self.notas = notas
    }
}
