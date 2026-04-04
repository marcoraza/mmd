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

    private lazy var encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
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

    // MARK: - Projects

    /// Fetch projects filtered by status.
    func fetchProjects(status: [StatusProjeto]) async throws -> [Project] {
        let statusValues = status.map { "\"\($0.rawValue)\"" }.joined(separator: ",")
        let queryItems = [
            URLQueryItem(name: "status", value: "in.(\(statusValues))"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "data_inicio.asc")
        ]
        let request = try makeRequest(path: "/rest/v1/projetos", queryItems: queryItems)
        return try await perform(request)
    }

    // MARK: - Packing List

    /// Fetch packing list items for a project, with joined equipment data.
    func fetchPackingList(projectId: UUID) async throws -> [PackingListItem] {
        let queryItems = [
            URLQueryItem(name: "projeto_id", value: "eq.\(projectId.uuidString)"),
            URLQueryItem(name: "select", value: "*,item:items(*)")
        ]
        let request = try makeRequest(path: "/rest/v1/packing_list", queryItems: queryItems)
        return try await perform(request)
    }

    // MARK: - Movements

    /// Fetch movements for a project, optionally filtered by type.
    func fetchProjectMovements(projectId: UUID, tipo: TipoMovimentacao? = nil) async throws -> [Movement] {
        var queryItems = [
            URLQueryItem(name: "projeto_id", value: "eq.\(projectId.uuidString)"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "timestamp.desc")
        ]
        if let tipo = tipo {
            queryItems.append(URLQueryItem(name: "tipo", value: "eq.\(tipo.rawValue)"))
        }
        let request = try makeRequest(path: "/rest/v1/movimentacoes", queryItems: queryItems)
        return try await perform(request)
    }

    // MARK: - QR Code Resolution

    /// Resolve a QR code string to a serial number with equipment data.
    func resolveQRCode(_ code: String) async throws -> SerialNumber? {
        let queryItems = [
            URLQueryItem(name: "qr_code", value: "eq.\(code)"),
            URLQueryItem(name: "select", value: "*,item:items(*)")
        ]
        let request = try makeRequest(path: "/rest/v1/serial_numbers", queryItems: queryItems)
        let results: [SerialNumber] = try await perform(request)
        return results.first
    }

    // MARK: - Serial Numbers by IDs

    /// Fetch serial numbers by their IDs, with joined equipment data.
    func fetchSerialsByIds(_ ids: [UUID]) async throws -> [SerialNumber] {
        guard !ids.isEmpty else { return [] }
        let quoted = ids.map { "\"\($0.uuidString)\"" }.joined(separator: ",")
        let queryItems = [
            URLQueryItem(name: "id", value: "in.(\(quoted))"),
            URLQueryItem(name: "select", value: "*,item:items(*)")
        ]
        let request = try makeRequest(path: "/rest/v1/serial_numbers", queryItems: queryItems)
        return try await perform(request)
    }

    // MARK: - Checkout Operations

    /// Register a checkout: batch POST movements + bulk PATCH serial statuses to EM_CAMPO.
    func registerCheckout(
        projectId: UUID,
        serials: [(serialId: UUID, currentStatus: String, metodoScan: MetodoScan)]
    ) async throws {
        // 1. POST movimentacoes
        let movements = serials.map { serial in
            CheckoutMovementRequest(
                serialNumberId: serial.serialId,
                projetoId: projectId,
                statusAnterior: serial.currentStatus,
                metodoScan: serial.metodoScan.rawValue
            )
        }

        let movementBody = try encoder.encode(movements)
        let movementRequest = try makeRequest(
            path: "/rest/v1/movimentacoes",
            method: "POST",
            body: movementBody,
            additionalHeaders: ["Prefer": "return=minimal"]
        )
        try await performVoid(movementRequest)

        // 2. PATCH serial_numbers status to EM_CAMPO
        let serialIds = serials.map { "\"\($0.serialId.uuidString)\"" }.joined(separator: ",")
        let statusBody = try encoder.encode(["status": StatusSerial.emCampo.rawValue])
        let patchRequest = try makeRequest(
            path: "/rest/v1/serial_numbers",
            method: "PATCH",
            queryItems: [URLQueryItem(name: "id", value: "in.(\(serialIds))")],
            body: statusBody,
            additionalHeaders: ["Prefer": "return=minimal"]
        )
        try await performVoid(patchRequest)

        logger.info("Checkout registered: \(serials.count) items for project \(projectId)")
    }

    // MARK: - Return Operations

    /// Register returns: batch POST movements + PATCH serials by outcome.
    func registerReturn(
        projectId: UUID,
        returns: [(serialId: UUID, tipo: TipoMovimentacao, statusNovo: String, desgaste: Int?, metodoScan: MetodoScan, notas: String?)]
    ) async throws {
        // 1. POST all movimentacoes
        let movements = returns.map { r in
            ReturnMovementRequest(
                serialNumberId: r.serialId,
                projetoId: projectId,
                tipo: r.tipo,
                statusNovo: r.statusNovo,
                metodoScan: r.metodoScan.rawValue,
                notas: r.notas
            )
        }

        let movementBody = try encoder.encode(movements)
        let movementRequest = try makeRequest(
            path: "/rest/v1/movimentacoes",
            method: "POST",
            body: movementBody,
            additionalHeaders: ["Prefer": "return=minimal"]
        )
        try await performVoid(movementRequest)

        // 2. Bulk PATCH OK items (status -> DISPONIVEL)
        let okIds = returns.filter { $0.statusNovo == StatusSerial.disponivel.rawValue }
            .map { "\"\($0.serialId.uuidString)\"" }
        if !okIds.isEmpty {
            let okBody = try encoder.encode(["status": StatusSerial.disponivel.rawValue])
            let okPatch = try makeRequest(
                path: "/rest/v1/serial_numbers",
                method: "PATCH",
                queryItems: [URLQueryItem(name: "id", value: "in.(\(okIds.joined(separator: ",")))")],
                body: okBody,
                additionalHeaders: ["Prefer": "return=minimal"]
            )
            try await performVoid(okPatch)
        }

        // 3. Individual PATCH for defect items (varying desgaste values)
        let defectItems = returns.filter { $0.statusNovo == StatusSerial.manutencao.rawValue }
        for item in defectItems {
            var updates: [String: Any] = ["status": StatusSerial.manutencao.rawValue]
            if let desgaste = item.desgaste {
                updates["desgaste"] = desgaste
            }
            let body = try JSONSerialization.data(withJSONObject: updates)
            let patch = try makeRequest(
                path: "/rest/v1/serial_numbers",
                method: "PATCH",
                queryItems: [URLQueryItem(name: "id", value: "eq.\(item.serialId.uuidString)")],
                body: body,
                additionalHeaders: ["Prefer": "return=minimal"]
            )
            try await performVoid(patch)
        }

        logger.info("Return registered: \(returns.count) items for project \(projectId)")
    }

    // MARK: - Project Status

    /// Update a project's status.
    func updateProjectStatus(projectId: UUID, status: StatusProjeto) async throws {
        let body = try encoder.encode(["status": status.rawValue])
        let request = try makeRequest(
            path: "/rest/v1/projetos",
            method: "PATCH",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(projectId.uuidString)")],
            body: body,
            additionalHeaders: ["Prefer": "return=minimal"]
        )
        try await performVoid(request)

        logger.info("Project \(projectId) status updated to \(status.rawValue)")
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

    /// Build an authenticated URLRequest with configurable HTTP method and body.
    private func makeRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        additionalHeaders: [String: String] = [:]
    ) throws -> URLRequest {
        guard !baseURL.isEmpty, !apiKey.isEmpty else {
            throw APIError.notConfigured
        }

        let sanitizedBase = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL

        guard var components = URLComponents(string: sanitizedBase + path) else {
            throw APIError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = body
        }

        for (key, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        #if DEBUG
        logger.debug("Request: \(method) \(url.absoluteString)")
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

    /// Execute a request expecting no decoded response body (writes with Prefer: return=minimal).
    private func performVoid(_ request: URLRequest) async throws {
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
        #endif

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            let apiError = APIError.httpError(statusCode: httpResponse.statusCode, body: body)
            lastError = apiError
            throw apiError
        }
    }
}
