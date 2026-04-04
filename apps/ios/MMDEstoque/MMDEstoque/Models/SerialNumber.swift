import Foundation

// MARK: - StatusSerial

enum StatusSerial: String, Codable, CaseIterable, Identifiable {
    case disponivel = "DISPONIVEL"
    case packed = "PACKED"
    case emCampo = "EM_CAMPO"
    case retornando = "RETORNANDO"
    case manutencao = "MANUTENCAO"
    case emprestado = "EMPRESTADO"
    case vendido = "VENDIDO"
    case baixa = "BAIXA"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .disponivel: return "Disponivel"
        case .packed: return "Packed"
        case .emCampo: return "Em Campo"
        case .retornando: return "Retornando"
        case .manutencao: return "Manutencao"
        case .emprestado: return "Emprestado"
        case .vendido: return "Vendido"
        case .baixa: return "Baixa"
        }
    }

    /// Whether this status means the unit is actively in use or unavailable.
    var isActive: Bool {
        switch self {
        case .disponivel, .packed: return false
        case .emCampo, .retornando: return true
        case .manutencao, .emprestado, .vendido, .baixa: return false
        }
    }

    /// Whether the unit can be assigned to a new job.
    var isAvailable: Bool {
        self == .disponivel
    }
}

// MARK: - Estado

enum Estado: String, Codable, CaseIterable, Identifiable {
    case novo = "NOVO"
    case semiNovo = "SEMI_NOVO"
    case usado = "USADO"
    case recondicionado = "RECONDICIONADO"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .novo: return "Novo"
        case .semiNovo: return "Semi-Novo"
        case .usado: return "Usado"
        case .recondicionado: return "Recondicionado"
        }
    }

    /// Depreciation factor used in value calculation.
    var fatorDepreciacao: Double {
        switch self {
        case .novo: return 1.00
        case .semiNovo: return 0.85
        case .usado: return 0.65
        case .recondicionado: return 0.50
        }
    }
}

// MARK: - SerialNumber

/// Maps to the Supabase "serial_numbers" table.
struct SerialNumber: Identifiable, Codable, Hashable {
    let id: UUID
    var itemId: UUID
    var codigoInterno: String
    var serialFabrica: String?
    var tagRfid: String?
    var qrCode: String?
    var status: StatusSerial
    var estado: Estado
    var desgaste: Int
    var depreciacaoPct: Double?
    var valorAtual: Double?
    var localizacao: String?
    var notas: String?
    var createdAt: Date?
    var updatedAt: Date?

    /// Optional nested equipment, populated when the API returns joined data.
    var item: Equipment?

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case codigoInterno = "codigo_interno"
        case serialFabrica = "serial_fabrica"
        case tagRfid = "tag_rfid"
        case qrCode = "qr_code"
        case status
        case estado
        case desgaste
        case depreciacaoPct = "depreciacao_pct"
        case valorAtual = "valor_atual"
        case localizacao
        case notas
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case item
    }

    // MARK: - Hashable (exclude optional nested item to avoid issues)

    static func == (lhs: SerialNumber, rhs: SerialNumber) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - SerialNumber + Computed Values

extension SerialNumber {
    /// Calculates the current value based on market value, wear, and condition state.
    /// Formula: valorOriginal * (desgaste / 5) * fatorEstado
    func calcularValorAtual(valorOriginal: Double) -> Double {
        let fatorDesgaste = Double(desgaste) / 5.0
        return valorOriginal * fatorDesgaste * estado.fatorDepreciacao
    }

    /// Wear level description.
    var desgasteLabel: String {
        switch desgaste {
        case 5: return "Excelente"
        case 4: return "Bom"
        case 3: return "Regular"
        case 2: return "Desgastado"
        case 1: return "Critico"
        default: return "Desconhecido"
        }
    }

    /// Formatted current value, e.g. "R$ 800,00".
    var valorAtualFormatado: String? {
        guard let valor = valorAtual else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: valor))
    }
}
