import Foundation

// MARK: - StatusProjeto

/// Status do Evento. As rotas e o modelo interno ainda usam `projetos`, mas o
/// produto fala Evento.
///
/// Ordem e conjunto vêm de `docs/contratos-api.md` seção 4.2. `MONTAGEM` existe
/// no banco desde a importação Event Pro e é estado de check-out válido junto
/// com `CONFIRMADO` (o legado iOS não conhecia esse caso).
enum StatusProjeto: String, Codable, CaseIterable, Identifiable {
    case planejamento = "PLANEJAMENTO"
    case confirmado = "CONFIRMADO"
    case montagem = "MONTAGEM"
    case emCampo = "EM_CAMPO"
    case finalizado = "FINALIZADO"
    case cancelado = "CANCELADO"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .planejamento: return "Planejamento"
        case .confirmado: return "Confirmado"
        case .montagem: return "Montagem"
        case .emCampo: return "Em Campo"
        case .finalizado: return "Finalizado"
        case .cancelado: return "Cancelado"
        }
    }

    /// Estados em que o check-out é permitido sem override.
    var permiteCheckout: Bool {
        self == .confirmado || self == .montagem
    }

    /// Estado em que o retorno é permitido.
    var permiteRetorno: Bool {
        self == .emCampo
    }

    /// Eventos que a Home mostra por padrão.
    static let abertos: [StatusProjeto] = [.confirmado, .montagem, .emCampo]
}

// MARK: - Project

/// Espelha a tabela `projetos` do Supabase.
struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var nome: String
    var cliente: String? = nil
    var dataInicio: String? = nil
    var dataFim: String? = nil
    var local: String? = nil
    var status: StatusProjeto
    var notas: String? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case nome
        case cliente
        case dataInicio = "data_inicio"
        case dataFim = "data_fim"
        case local
        case status
        case notas
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Project + Date Helpers

extension Project {

    /// Coluna `date` do Postgres: yyyy-MM-dd, sem fuso.
    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// Exibição: "15 abr 2026".
    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        f.locale = Locale(identifier: "pt_BR")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    var dataInicioDate: Date? {
        guard let s = dataInicio else { return nil }
        return Self.dateOnlyFormatter.date(from: s)
    }

    var dataFimDate: Date? {
        guard let s = dataFim else { return nil }
        return Self.dateOnlyFormatter.date(from: s)
    }

    var dataInicioFormatado: String? {
        guard let date = dataInicioDate else { return nil }
        return Self.displayFormatter.string(from: date)
    }

    var dataFimFormatado: String? {
        guard let date = dataFimDate else { return nil }
        return Self.displayFormatter.string(from: date)
    }

    var periodoFormatado: String? {
        switch (dataInicioFormatado, dataFimFormatado) {
        case let (inicio?, fim?) where inicio == fim:
            return inicio
        case let (inicio?, fim?):
            return "\(inicio) a \(fim)"
        case let (inicio?, nil):
            return inicio
        case let (nil, fim?):
            return fim
        default:
            return nil
        }
    }
}
