import Foundation

// MARK: - Categoria

enum Categoria: String, Codable, CaseIterable, Identifiable {
    case iluminacao = "ILUMINACAO"
    case audio = "AUDIO"
    case cabo = "CABO"
    case energia = "ENERGIA"
    case estrutura = "ESTRUTURA"
    case efeito = "EFEITO"
    case video = "VIDEO"
    case acessorio = "ACESSORIO"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iluminacao: return "Iluminacao"
        case .audio: return "Audio"
        case .cabo: return "Cabo"
        case .energia: return "Energia"
        case .estrutura: return "Estrutura"
        case .efeito: return "Efeito"
        case .video: return "Video"
        case .acessorio: return "Acessorio"
        }
    }

    var prefix: String {
        switch self {
        case .iluminacao: return "ILU"
        case .audio: return "AUD"
        case .cabo: return "CAB"
        case .energia: return "ENE"
        case .estrutura: return "EST"
        case .efeito: return "EFE"
        case .video: return "VID"
        case .acessorio: return "ACE"
        }
    }
}

// MARK: - TipoRastreamento

enum TipoRastreamento: String, Codable, CaseIterable, Identifiable {
    case individual = "INDIVIDUAL"
    case lote = "LOTE"
    case bulk = "BULK"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .individual: return "Individual"
        case .lote: return "Lote"
        case .bulk: return "Bulk"
        }
    }
}

// MARK: - Equipment

/// Maps to the Supabase "items" table.
struct Equipment: Identifiable, Codable, Hashable {
    let id: UUID
    var nome: String
    var categoria: Categoria
    var subcategoria: String?
    var marca: String?
    var modelo: String?
    var tipoRastreamento: TipoRastreamento?
    var quantidadeTotal: Int?
    var valorMercadoUnitario: Double?
    var fotoUrl: String?
    var notas: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case nome
        case categoria
        case subcategoria
        case marca
        case modelo
        case tipoRastreamento = "tipo_rastreamento"
        case quantidadeTotal = "quantidade_total"
        case valorMercadoUnitario = "valor_mercado_unitario"
        case fotoUrl = "foto_url"
        case notas
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Equipment + Display Helpers

extension Equipment {
    /// Full display name: "Marca Modelo" or just nome if brand/model are missing.
    var displayName: String {
        let parts = [marca, modelo].compactMap { $0 }
        return parts.isEmpty ? nome : parts.joined(separator: " ")
    }

    /// Formatted unit market value, e.g. "R$ 1.200,00".
    var valorMercadoFormatado: String? {
        guard let valor = valorMercadoUnitario else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: valor))
    }
}
