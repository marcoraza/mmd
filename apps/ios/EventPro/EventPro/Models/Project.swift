import Foundation

// MARK: - StatusProjeto

enum StatusProjeto: String, Codable, CaseIterable, Identifiable {
    case planejamento = "PLANEJAMENTO"
    case confirmado = "CONFIRMADO"
    case emCampo = "EM_CAMPO"
    case finalizado = "FINALIZADO"
    case cancelado = "CANCELADO"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .planejamento: return "Planejamento"
        case .confirmado: return "Confirmado"
        case .emCampo: return "Em Campo"
        case .finalizado: return "Finalizado"
        case .cancelado: return "Cancelado"
        }
    }
}

// MARK: - Project

/// Maps to the Supabase "projetos" table.
struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var nome: String
    var cliente: String? = nil
    var dataInicio: String? = nil
    var dataFim: String? = nil
    var local: String? = nil
    var status: StatusProjeto
    var notas: String? = nil
    /// Latitude WGS84 do pin de destino. Opcional; existe em par com longitude.
    var destinoLatitude: Double? = nil
    /// Longitude WGS84 do pin de destino. Opcional; existe em par com latitude.
    var destinoLongitude: Double? = nil
    /// Momento da última gravação do pin. Null quando o Evento ainda não tem destino.
    var destinoConfirmadoEm: Date? = nil
    /// Subconjunto da ficha com endereço humano (não reescreve o pin).
    var fichaEvento: EventoFichaDestino? = nil
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
        case destinoLatitude = "destino_latitude"
        case destinoLongitude = "destino_longitude"
        case destinoConfirmadoEm = "destino_confirmado_em"
        case fichaEvento = "ficha_evento"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// True quando o Evento tem pin de destino (par lat/lng).
    var hasDestino: Bool {
        destinoLatitude != nil && destinoLongitude != nil
    }

    /// Pin operacional, se completo.
    var destinoPin: DestinoPin? {
        guard let lat = destinoLatitude, let lng = destinoLongitude else { return nil }
        return DestinoPin(latitude: lat, longitude: lng, confirmadoEm: destinoConfirmadoEm)
    }

    /// Nome comercial do local: ficha.local → coluna local → nome do Evento.
    var localDisplayName: String {
        let fichaLocal = fichaEvento?.endereco?.local?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fichaLocal, !fichaLocal.isEmpty { return fichaLocal }
        if let local, !local.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return local
        }
        return nome
    }

    /// Endereço humano legível (não é o pin).
    var enderecoDisplayLine: String {
        let end = fichaEvento?.endereco
        let parts = [end?.endereco, end?.cidadeUf]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }

    /// Texto de partida da busca no Apple Maps.
    var prefillSearchQuery: String {
        let end = fichaEvento?.endereco
        let parts = [end?.local ?? local, end?.endereco, end?.cidadeUf]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: ", ") }
        return nome
    }

    mutating func apply(pin: DestinoPin?) {
        destinoLatitude = pin?.latitude
        destinoLongitude = pin?.longitude
        destinoConfirmadoEm = pin?.confirmadoEm
    }
}

// MARK: - Project + Date Helpers

extension Project {

    /// Shared date-only formatter for Postgres date columns (yyyy-MM-dd).
    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Shared display formatter: "15 abr 2026".
    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        f.locale = Locale(identifier: "pt_BR")
        return f
    }()

    /// Parsed start date.
    var dataInicioDate: Date? {
        guard let s = dataInicio else { return nil }
        return Self.dateOnlyFormatter.date(from: s)
    }

    /// Parsed end date.
    var dataFimDate: Date? {
        guard let s = dataFim else { return nil }
        return Self.dateOnlyFormatter.date(from: s)
    }

    /// Formatted start date, e.g. "15 abr 2026".
    var dataInicioFormatado: String? {
        guard let date = dataInicioDate else { return nil }
        return Self.displayFormatter.string(from: date)
    }

    /// Formatted end date, e.g. "20 abr 2026".
    var dataFimFormatado: String? {
        guard let date = dataFimDate else { return nil }
        return Self.displayFormatter.string(from: date)
    }
}
