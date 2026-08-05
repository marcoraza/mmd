import Foundation

// MARK: - Query

/// Parâmetros de `GET /api/seriais/busca` — docs/contratos-api.md seção 8.
///
/// Substitui a busca client-side do legado, que baixava o catálogo inteiro
/// (`fetchItems`) e filtrava em memória. `limit` acima de 100 não é erro: o
/// servidor reduz silenciosamente, e o cliente já manda dentro da faixa.
struct SerialBuscaQuery: Equatable {
    var q: String?
    var itemId: UUID?
    var semTag: Bool?
    var limit: Int
    var offset: Int

    static let defaultLimit = 25
    static let maxLimit = 100
    static let minQueryLength = 2
    static let maxQueryLength = 64

    init(
        q: String? = nil,
        itemId: UUID? = nil,
        semTag: Bool? = nil,
        limit: Int = SerialBuscaQuery.defaultLimit,
        offset: Int = 0
    ) {
        self.q = SerialBuscaQuery.normalizeTerm(q)
        self.itemId = itemId
        self.semTag = semTag
        self.limit = max(1, min(SerialBuscaQuery.maxLimit, limit))
        self.offset = max(0, offset)
    }

    /// Trim e descarte de termo vazio. O servidor exige 2 a 64 caracteres e
    /// recusa caractere fora de `[A-Za-z0-9._:\- ]` (anti-injeção de filtro
    /// PostgREST); `isTermValid` deixa o cliente errar cedo, sem round-trip.
    static func normalizeTerm(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static let allowedTermCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.formUnion(CharacterSet(charactersIn: "._:- "))
        return set
    }()

    var isTermValid: Bool {
        guard let q else { return true }
        guard q.count >= Self.minQueryLength, q.count <= Self.maxQueryLength else { return false }
        return q.unicodeScalars.allSatisfy { Self.allowedTermCharacters.contains($0) }
    }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let q {
            items.append(URLQueryItem(name: "q", value: q))
        }
        if let itemId {
            items.append(URLQueryItem(name: "item_id", value: itemId.uuidString.lowercased()))
        }
        if let semTag {
            items.append(URLQueryItem(name: "sem_tag", value: semTag ? "true" : "false"))
        }
        items.append(URLQueryItem(name: "limit", value: String(limit)))
        items.append(URLQueryItem(name: "offset", value: String(offset)))
        return items
    }

    /// Próxima página, preservando os filtros.
    func nextPage(loaded: Int) -> SerialBuscaQuery {
        var next = self
        next.offset = offset + loaded
        return next
    }
}

// MARK: - Response

/// Envelope de `GET /api/seriais/busca`. O envelope existe para carregar a
/// paginação; array puro e envelope não são compatíveis de forma aditiva.
struct SerialBuscaResponse: Codable, Hashable {
    var items: [SerialBuscaItem]
    var total: Int
    var limit: Int
    var offset: Int
    var hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case total
        case limit
        case offset
        case hasMore = "has_more"
    }
}

struct SerialBuscaItem: Codable, Hashable, Identifiable {
    var serialId: UUID
    var codigoInterno: String
    var itemNome: String?

    /// `null` quando o serial ainda não tem tag: é o caso alvo do fluxo de
    /// vínculo.
    var tagRfid: String?

    var id: UUID { serialId }

    var temTag: Bool { tagRfid != nil }

    enum CodingKeys: String, CodingKey {
        case serialId = "serial_id"
        case codigoInterno = "codigo_interno"
        case itemNome = "item_nome"
        case tagRfid = "tag_rfid"
    }
}
