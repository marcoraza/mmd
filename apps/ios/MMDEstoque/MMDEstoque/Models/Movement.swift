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
