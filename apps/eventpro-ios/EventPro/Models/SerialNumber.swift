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

    /// Unidade em uso ou fora do galpão.
    var isActive: Bool {
        switch self {
        case .disponivel, .packed: return false
        case .emCampo, .retornando: return true
        case .manutencao, .emprestado, .vendido, .baixa: return false
        }
    }

    /// Unidade pode ser alocada a um Evento novo.
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

    /// Fator de depreciação usado no cálculo de valor atual.
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

/// Espelha a tabela `serial_numbers` do Supabase.
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

    /// Item pai, preenchido quando a API devolve o join.
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

    // MARK: - Hashable (ignora o item aninhado)

    static func == (lhs: SerialNumber, rhs: SerialNumber) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - SerialNumber + Computed Values

extension SerialNumber {

    /// Valor Original x (Desgaste / 5) x Fator Estado.
    func calcularValorAtual(valorOriginal: Double) -> Double {
        let fatorDesgaste = Double(desgaste) / 5.0
        return valorOriginal * fatorDesgaste * estado.fatorDepreciacao
    }

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

    var valorAtualFormatado: String? {
        guard let valor = valorAtual else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: valor))
    }
}
