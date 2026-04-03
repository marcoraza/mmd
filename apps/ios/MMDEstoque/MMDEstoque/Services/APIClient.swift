import Foundation
import os.log

// MARK: - APIError

enum APIError: LocalizedError {
    case invalidURL
    case notConfigured
    case httpError(statusCode: Int, body: String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalida para a requisicao."
        case .notConfigured:
            return "Supabase nao configurado. Acesse Ajustes para inserir URL e chave."
        case .httpError(let code, let body):
            let detail = body.map { " — \($0)" } ?? ""
            return "Erro HTTP \(code)\(detail)"
        case .decodingError(let error):
            return "Falha ao decodificar resposta: \(error.localizedDescription)"
        case .networkError(let error):
            return "Erro de rede: \(error.localizedDescription)"
        }
    }
}

// MARK: - APIClient

/// HTTP client for the Supabase PostgREST API.
///
/// Uses URLSession directly (no Supabase SDK). Reads URL and anon key
/// from `AppConfig.shared` on every request so settings changes take
/// effect immediately.
@MainActor
final class APIClient: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isLoading = false
    @Published var lastError: APIError?

    // MARK: - Dependencies

    private let session: URLSession
    private let logger = Logger(subsystem: "com.mmd.estoque", category: "APIClient")

    private var baseURL: String { AppConfig.shared.supabaseUrl }
    private var apiKey: String { AppConfig.shared.supabaseAnonKey }

    // MARK: - Date Decoding

    /// Supabase/Postgres returns timestamps as ISO 8601 with fractional seconds
    /// and timezone, e.g. "2026-03-20T14:30:00.000000+00:00".
    private static let supabaseDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let supabaseDateFormatterFallback: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        // Models define their own CodingKeys for snake_case mapping,
        // so we do NOT set .convertFromSnakeCase here.
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            if let date = Self.supabaseDateFormatter.date(from: string) {
                return date
            }
            if let date = Self.supabaseDateFormatterFallback.date(from: string) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Data nao reconhecida: \(string)"
            )
        }
        return d
    }()

    // MARK: - Init

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - RFID Tag Resolution (primary use case)

    /// Resolve an array of RFID EPC tags against the database.
    ///
    /// Queries `serial_numbers` filtering by `tag_rfid` with a PostgREST
    /// `in` operator, joining the parent `items` table via foreign key
    /// embedding.
    ///
    /// - Parameter tags: EPC tag strings read from the RFID reader.
    /// - Returns: A tuple with resolved items (matched to equipment) and
    ///   tag strings that had no match in the database.
    func resolveRfidTags(_ tags: [String]) async throws -> (resolved: [ResolvedItem], unresolved: [String]) {
        guard !tags.isEmpty else {
            return (resolved: [], unresolved: [])
        }

        // PostgREST "in" filter: tag_rfid=in.("AAA","BBB","CCC")
        let quoted = tags.map { "\"\($0)\"" }.joined(separator: ",")
        let filterValue = "in.(\(quoted))"

        let queryItems = [
            URLQueryItem(name: "tag_rfid", value: filterValue),
            URLQueryItem(name: "select", value: "*,item:items(*)")
        ]

        let request = try makeRequest(path: "/rest/v1/serial_numbers", queryItems: queryItems)
        let serialNumbers: [SerialNumber] = try await perform(request)

        // Build resolved items from serial numbers that came back with a nested item.
        var resolved: [ResolvedItem] = []
        var matchedTags: Set<String> = []

        for sn in serialNumbers {
            guard let equipment = sn.item, let tag = sn.tagRfid else { continue }
            resolved.append(ResolvedItem(serialNumber: sn, equipment: equipment))
            matchedTags.insert(tag)
        }

        let unresolved = tags.filter { !matchedTags.contains($0) }

        logger.info("RFID resolve: \(tags.count) tags sent, \(resolved.count) resolved, \(unresolved.count) unresolved")

        return (resolved: resolved, unresolved: unresolved)
    }

    // MARK: - Items

    /// Fetch all equipment items, ordered by name ascending.
    func fetchItems() async throws -> [Equipment] {
        let queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "nome.asc")
        ]
        let request = try makeRequest(path: "/rest/v1/items", queryItems: queryItems)
        return try await perform(request)
    }

    // MARK: - Serial Numbers

    /// Fetch all serial numbers for a given equipment item.
    func fetchSerialNumbers(forItemId id: UUID) async throws -> [SerialNumber] {
        let queryItems = [
            URLQueryItem(name: "item_id", value: "eq.\(id.uuidString)"),
            URLQueryItem(name: "select", value: "*")
        ]
        let request = try makeRequest(path: "/rest/v1/serial_numbers", queryItems: queryItems)
        return try await perform(request)
    }

    // MARK: - Private Helpers

    /// Build an authenticated URLRequest for the Supabase REST API.
    private func makeRequest(path: String, queryItems: [URLQueryItem]) throws -> URLRequest {
        guard !baseURL.isEmpty, !apiKey.isEmpty else {
            throw APIError.notConfigured
        }

        // Strip trailing slash from base URL to avoid double slashes.
        let sanitizedBase = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL

        guard var components = URLComponents(string: sanitizedBase + path) else {
            throw APIError.invalidURL
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        #if DEBUG
        logger.debug("Request: \(request.httpMethod ?? "GET") \(url.absoluteString)")
        #endif

        return request
    }

    /// Execute a request and decode the JSON response into the expected type.
    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        isLoading = true
        lastError = nil

        defer { isLoading = false }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let apiError = APIError.networkError(error)
            lastError = apiError
            throw apiError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            let apiError = APIError.networkError(
                URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Resposta nao HTTP"])
            )
            lastError = apiError
            throw apiError
        }

        #if DEBUG
        logger.debug("Response: \(httpResponse.statusCode) (\(data.count) bytes)")
        if data.count < 2048, let bodyPreview = String(data: data, encoding: .utf8) {
            logger.debug("Body: \(bodyPreview)")
        }
        #endif

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            let apiError = APIError.httpError(statusCode: httpResponse.statusCode, body: body)
            lastError = apiError
            throw apiError
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let apiError = APIError.decodingError(error)
            lastError = apiError

            #if DEBUG
            logger.error("Decoding failed: \(error)")
            if let bodyString = String(data: data, encoding: .utf8) {
                logger.error("Raw response: \(bodyString)")
            }
            #endif

            throw apiError
        }
    }
}
