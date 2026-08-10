import Foundation
import os.log

// MARK: - APIError

enum APIError: LocalizedError {
    case invalidURL
    case notConfigured
    case webApiNotConfigured
    case sessionExpired
    case invalidRequest(String)
    case httpError(statusCode: Int, body: String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalida para a requisicao."
        case .notConfigured:
            return "Supabase nao configurado. Acesse Ajustes para inserir URL e chave."
        case .webApiNotConfigured:
            return "API Web nao configurada. Acesse Ajustes para ativar operacoes reais."
        case .sessionExpired:
            return "Sessão expirada. Faça login novamente."
        case .invalidRequest(let message):
            return message
        case .httpError(let code, let body):
            let detail = body.map { ": \($0)" } ?? ""
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
    private let authState: AuthState
    private let logger = Logger(subsystem: "com.mmd.estoque", category: "APIClient")

    private var baseURL: String { AppConfig.shared.supabaseUrl }
    private var apiKey: String { AppConfig.shared.supabaseAnonKey }
    private var webApiBaseURL: String { AppConfig.shared.webApiUrl }
    private var webApiAuthToken: String { AppConfig.shared.webApiAuthToken }
    private var trimmedWebApiAuthToken: String {
        webApiAuthToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Em DEBUG, override manual do token tem precedência sobre a sessão.
    private var isUsingDebugAuthOverride: Bool {
        #if DEBUG
        return !trimmedWebApiAuthToken.isEmpty
        #else
        return false
        #endif
    }

    // MARK: - Date Decoding

    /// Supabase/Postgres returns timestamps as ISO 8601 with fractional seconds
    /// and timezone, e.g. "2026-03-20T14:30:00.000000+00:00".
    // ISO8601DateFormatter é thread-safe, pode viver fora do main actor.
    nonisolated(unsafe) private static let supabaseDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let supabaseDateFormatterFallback: ISO8601DateFormatter = {
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

    init(
        session: URLSession = .shared,
        authState: AuthState
    ) {
        self.session = session
        self.authState = authState
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

        let request = try await makeRequest(path: "/rest/v1/serial_numbers", queryItems: queryItems)
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

    /// Record RFID scan rows through the shared web API, resolving known tags
    /// and preserving unknown tags for audit/onboarding.
    func recordRfidScans(
        tags: [String],
        contexto: RfidScanContext,
        projectId: UUID? = nil,
        reader: RfidScanReaderRequest? = nil
    ) async throws -> RfidScanResponse {
        guard !tags.isEmpty else {
            return RfidScanResponse(resolved: [], unresolved: [], scanIds: [])
        }

        let body = try encoder.encode(
            RfidScanRequest(
                tags: tags,
                contexto: contexto,
                projetoId: projectId,
                reader: reader
            )
        )
        let request = try await makeWebApiRequest(
            path: "/api/rfid/scans",
            method: "POST",
            body: body
        )
        return try await perform(request)
    }

    /// Persist the scan batch in the web API, then fetch full serial/item
    /// records for screens that need packing-list matching.
    func recordAndResolveRfidTags(
        tags: [String],
        contexto: RfidScanContext,
        projectId: UUID? = nil,
        reader: RfidScanReaderRequest? = nil
    ) async throws -> (resolved: [ResolvedItem], unresolved: [String]) {
        guard AppConfig.shared.isWebApiConfigured else {
            return try await resolveRfidTags(tags)
        }

        let scan = try await recordRfidScans(
            tags: tags,
            contexto: contexto,
            projectId: projectId,
            reader: reader
        )
        let serialIds = scan.resolved.map(\.serialId)
        let serials = try await fetchSerialsByIds(serialIds)
        let serialsById = Dictionary(uniqueKeysWithValues: serials.map { ($0.id, $0) })

        var resolved: [ResolvedItem] = []
        var unresolved = scan.unresolved

        for match in scan.resolved {
            guard
                let serial = serialsById[match.serialId],
                let equipment = serial.item
            else {
                unresolved.append(match.tagRfid)
                continue
            }

            resolved.append(ResolvedItem(serialNumber: serial, equipment: equipment))
        }

        return (resolved: resolved, unresolved: unresolved)
    }

    // MARK: - Items

    /// Fetch all equipment items, ordered by name ascending.
    func fetchItems() async throws -> [Equipment] {
        let queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "nome.asc")
        ]
        let request = try await makeRequest(path: "/rest/v1/items", queryItems: queryItems)
        return try await perform(request)
    }

    // MARK: - Serial Numbers

    /// Fetch all serial numbers for a given equipment item.
    func fetchSerialNumbers(forItemId id: UUID) async throws -> [SerialNumber] {
        let queryItems = [
            URLQueryItem(name: "item_id", value: "eq.\(id.uuidString)"),
            URLQueryItem(name: "select", value: "*")
        ]
        let request = try await makeRequest(path: "/rest/v1/serial_numbers", queryItems: queryItems)
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
        let request = try await makeRequest(path: "/rest/v1/projetos", queryItems: queryItems)
        return try await perform(request)
    }

    /// Role do perfil autenticado (self-read em `profiles`).
    func fetchMyRole() async throws -> UserRole {
        let queryItems = [
            URLQueryItem(name: "select", value: "role"),
            URLQueryItem(name: "limit", value: "1")
        ]
        struct ProfileRoleRow: Decodable {
            let role: UserRole
        }
        let request = try await makeRequest(path: "/rest/v1/profiles", queryItems: queryItems)
        let rows: [ProfileRoleRow] = try await perform(request)
        return rows.first?.role ?? .viewer
    }

    // MARK: - Packing List

    /// Fetch packing list items for a project, with joined equipment data.
    func fetchPackingList(projectId: UUID) async throws -> [PackingListItem] {
        let queryItems = [
            URLQueryItem(name: "projeto_id", value: "eq.\(projectId.uuidString)"),
            URLQueryItem(name: "select", value: "*,item:items(*)")
        ]
        let request = try await makeRequest(path: "/rest/v1/packing_list", queryItems: queryItems)
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
        let request = try await makeRequest(path: "/rest/v1/movimentacoes", queryItems: queryItems)
        return try await perform(request)
    }

    // MARK: - QR Code Resolution

    /// Resolve a QR code string to a serial number with equipment data.
    func resolveQRCode(_ code: String) async throws -> SerialNumber? {
        let queryItems = [
            URLQueryItem(name: "qr_code", value: "eq.\(code)"),
            URLQueryItem(name: "select", value: "*,item:items(*)")
        ]
        let request = try await makeRequest(path: "/rest/v1/serial_numbers", queryItems: queryItems)
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
        let request = try await makeRequest(path: "/rest/v1/serial_numbers", queryItems: queryItems)
        return try await perform(request)
    }

    /// Fetch real serial numbers that belong to the given item types, with
    /// joined equipment data, capped by `limit`.
    func fetchSerialsByItemIds(_ itemIds: [UUID], limit: Int) async throws -> [SerialNumber] {
        guard !itemIds.isEmpty else { return [] }
        let quoted = itemIds.map { "\"\($0.uuidString)\"" }.joined(separator: ",")
        let queryItems = [
            URLQueryItem(name: "item_id", value: "in.(\(quoted))"),
            URLQueryItem(name: "select", value: "*,item:items(*)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        let request = try await makeRequest(path: "/rest/v1/serial_numbers", queryItems: queryItems)
        return try await perform(request)
    }

    // MARK: - Inventory Snapshot (Home)

    /// Linha enxuta de um serial pra agregacao na Home: status, desgaste e se
    /// tem tag. Decode tolerante de proposito: status fora do enum vira nil (a
    /// linha e ignorada na agregacao) e desgaste ausente cai pro default 3.
    /// Assim uma unica linha suja nao derruba os contadores da tela principal.
    struct SerialSnapshotRow: Decodable {
        let status: StatusSerial?
        let desgaste: Int
        let tagRfid: String?

        enum CodingKeys: String, CodingKey {
            case status
            case desgaste
            case tagRfid = "tag_rfid"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let rawStatus = try c.decodeIfPresent(String.self, forKey: .status)
            self.status = rawStatus.flatMap(StatusSerial.init(rawValue:))
            self.desgaste = (try? c.decode(Int.self, forKey: .desgaste)) ?? 3
            self.tagRfid = try c.decodeIfPresent(String.self, forKey: .tagRfid)
        }
    }

    /// Snapshot enxuto de todos os seriais (so status, desgaste e tag) pros
    /// contadores e alertas da Home. Pagina via Range pra furar o teto de
    /// linhas do PostgREST (Supabase corta em 1000 por resposta): sem isso, um
    /// estoque acima do teto faria os contadores mentirem pra menos.
    func fetchSerialSnapshot() async throws -> [SerialSnapshotRow] {
        let pageSize = 1000
        var all: [SerialSnapshotRow] = []
        var offset = 0

        while true {
            var request = try await makeRequest(
                path: "/rest/v1/serial_numbers",
                queryItems: [URLQueryItem(name: "select", value: "status,desgaste,tag_rfid")]
            )
            request.setValue("\(offset)-\(offset + pageSize - 1)", forHTTPHeaderField: "Range")
            let page: [SerialSnapshotRow] = try await perform(request)
            all.append(contentsOf: page)
            if page.count < pageSize { break }
            offset += pageSize
        }

        return all
    }

    // MARK: - Checkout Operations

    /// Execute checkout through the shared operational web boundary.
    func checkoutProject(
        projectId: UUID,
        metodoScan: MetodoScan,
        overrideReason: String? = nil
    ) async throws -> CheckoutProjectResponse {
        let body = try encoder.encode(
            CheckoutProjectRequest(
                metodo: metodoScan.rawValue,
                overrideReason: overrideReason
            )
        )
        let request = try await makeWebApiRequest(
            path: "/api/eventos/\(projectId.uuidString)/checkout",
            method: "POST",
            body: body
        )
        return try await perform(request)
    }

    /// Legacy direct checkout path. New checkout flow uses checkoutProject(projectId:metodoScan:).
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
        let movementRequest = try await makeRequest(
            path: "/rest/v1/movimentacoes",
            method: "POST",
            body: movementBody,
            additionalHeaders: ["Prefer": "return=minimal"]
        )
        try await performVoid(movementRequest)

        // 2. PATCH serial_numbers status to EM_CAMPO
        let serialIds = serials.map { "\"\($0.serialId.uuidString)\"" }.joined(separator: ",")
        let statusBody = try encoder.encode(["status": StatusSerial.emCampo.rawValue])
        let patchRequest = try await makeRequest(
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

    /// Execute return through the shared operational web boundary.
    func returnProject(
        projectId: UUID,
        metodoScan: MetodoScan,
        items: [ReturnProjectItemRequest]
    ) async throws -> ReturnProjectResponse {
        let body = try encoder.encode(
            ReturnProjectRequest(
                metodo: metodoScan.rawValue,
                items: items
            )
        )
        let request = try await makeWebApiRequest(
            path: "/api/eventos/\(projectId.uuidString)/retorno",
            method: "POST",
            body: body
        )
        return try await perform(request)
    }

    /// Legacy direct return path. New return flow uses returnProject(projectId:metodoScan:items:).
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
        let movementRequest = try await makeRequest(
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
            let okPatch = try await makeRequest(
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
            let patch = try await makeRequest(
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
        let request = try await makeRequest(
            path: "/rest/v1/projetos",
            method: "PATCH",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(projectId.uuidString)")],
            body: body,
            additionalHeaders: ["Prefer": "return=minimal"]
        )
        try await performVoid(request)

        logger.info("Project \(projectId) status updated to \(status.rawValue)")
    }

    // MARK: - Evento destino (pin)

    /// Atualiza somente os campos do pin de destino do Evento.
    ///
    /// - Parameters:
    ///   - projectId: ID do Evento (`projetos.id`).
    ///   - latitude: Latitude WGS84, ou `nil` para limpar o pin (junto com longitude).
    ///   - longitude: Longitude WGS84, ou `nil` para limpar o pin (junto com latitude).
    ///   - confirmadoEm: Timestamp da gravação; ignorado na limpeza. Default: agora.
    ///
    /// Par incompleto (só lat ou só lng) é rejeitado no cliente antes da rede.
    /// Payload mínimo: apenas `destino_latitude`, `destino_longitude`, `destino_confirmado_em`.
    /// nulls explícitos limpam o pin no PostgREST (campo omitido não apaga).
    func updateEventoDestino(
        projectId: UUID,
        latitude: Double?,
        longitude: Double?,
        confirmadoEm: Date = Date()
    ) async throws {
        switch (latitude, longitude) {
        case (nil, nil):
            break
        case (.some(let lat), .some(let lng)):
            guard (-90...90).contains(lat), (-180...180).contains(lng) else {
                throw APIError.invalidRequest("Coordenadas do destino fora da faixa válida")
            }
        default:
            throw APIError.invalidRequest(
                "Destino exige latitude e longitude juntas, ou ambas nulas"
            )
        }

        let payload: [String: Any]
        if let latitude, let longitude {
            payload = [
                "destino_latitude": latitude,
                "destino_longitude": longitude,
                "destino_confirmado_em": Self.supabaseDateFormatter.string(from: confirmadoEm)
            ]
        } else {
            payload = [
                "destino_latitude": NSNull(),
                "destino_longitude": NSNull(),
                "destino_confirmado_em": NSNull()
            ]
        }

        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = try await makeRequest(
            path: "/rest/v1/projetos",
            method: "PATCH",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(projectId.uuidString)")],
            body: body,
            additionalHeaders: ["Prefer": "return=minimal"]
        )
        try await performVoid(request)

        logger.info("Project \(projectId) destino atualizado")
    }

    /// Vincula uma tag RFID a um serial: PATCH em `serial_numbers` gravando
    /// `tag_rfid`. Espelha `updateProjectStatus`. Backend da trilha Etiquetar.
    func linkTag(serialId: UUID, tagRfid: String) async throws {
        let body = try encoder.encode(["tag_rfid": tagRfid])
        let request = try await makeRequest(
            path: "/rest/v1/serial_numbers",
            method: "PATCH",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(serialId.uuidString)")],
            body: body,
            additionalHeaders: ["Prefer": "return=minimal"]
        )
        try await performVoid(request)

        logger.info("Serial \(serialId) linked to tag \(tagRfid)")
    }

    // MARK: - Private Helpers

    /// Resolve o Bearer: DEBUG override tem prioridade; senão sessão (sem fallback anon).
    private func resolveBearerToken() async throws -> String {
        #if DEBUG
        if isUsingDebugAuthOverride {
            return trimmedWebApiAuthToken
        }
        #endif

        do {
            return try await authState.validAccessToken()
        } catch AuthError.notAuthenticated, AuthError.sessionExpired {
            throw APIError.sessionExpired
        } catch AuthError.notConfigured {
            throw APIError.notConfigured
        } catch AuthError.invalidCredentials {
            throw APIError.sessionExpired
        } catch AuthError.network(let error) {
            throw APIError.networkError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    /// Build an authenticated URLRequest for the Supabase REST API.
    private func makeRequest(path: String, queryItems: [URLQueryItem]) async throws -> URLRequest {
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

        let bearer = try await resolveBearerToken()

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
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
    ) async throws -> URLRequest {
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

        let bearer = try await resolveBearerToken()

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
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

    /// Build a request for the shared web API used by mobile-only operational boundaries.
    private func makeWebApiRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> URLRequest {
        guard !webApiBaseURL.isEmpty else {
            throw APIError.webApiNotConfigured
        }

        let sanitizedBase = webApiBaseURL.hasSuffix("/") ? String(webApiBaseURL.dropLast()) : webApiBaseURL

        guard let url = URL(string: sanitizedBase + path) else {
            throw APIError.invalidURL
        }

        let bearer = try await resolveBearerToken()

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")

        if let body = body {
            request.httpBody = body
        }

        #if DEBUG
        logger.debug("Web API Request: \(method) \(url.absoluteString)")
        #endif

        return request
    }

    /// Execute a request and decode the JSON response into the expected type.
    private func perform<T: Decodable>(_ request: URLRequest, allowRefreshRetry: Bool = true) async throws -> T {
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

        if httpResponse.statusCode == 401,
           allowRefreshRetry,
           !isUsingDebugAuthOverride {
            let newToken: String
            do {
                newToken = try await refreshedBearerTokenAfterUnauthorized()
            } catch let apiError as APIError {
                lastError = apiError
                throw apiError
            }
            var retry = request
            retry.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            return try await perform(retry, allowRefreshRetry: false)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            if httpResponse.statusCode == 401 {
                if !isUsingDebugAuthOverride {
                    await authState.invalidateSession()
                }
                let apiError = APIError.sessionExpired
                lastError = apiError
                throw apiError
            }
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
    private func performVoid(_ request: URLRequest, allowRefreshRetry: Bool = true) async throws {
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

        if httpResponse.statusCode == 401,
           allowRefreshRetry,
           !isUsingDebugAuthOverride {
            let newToken: String
            do {
                newToken = try await refreshedBearerTokenAfterUnauthorized()
            } catch let apiError as APIError {
                lastError = apiError
                throw apiError
            }
            var retry = request
            retry.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            try await performVoid(retry, allowRefreshRetry: false)
            return
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                if !isUsingDebugAuthOverride {
                    await authState.invalidateSession()
                }
                let apiError = APIError.sessionExpired
                lastError = apiError
                throw apiError
            }
            let body = String(data: data, encoding: .utf8)
            let apiError = APIError.httpError(statusCode: httpResponse.statusCode, body: body)
            lastError = apiError
            throw apiError
        }
    }

    private func refreshedBearerTokenAfterUnauthorized() async throws -> String {
        do {
            return try await authState.refreshedAccessToken()
        } catch AuthError.notAuthenticated, AuthError.sessionExpired, AuthError.invalidCredentials {
            throw APIError.sessionExpired
        } catch AuthError.notConfigured {
            throw APIError.notConfigured
        } catch AuthError.network(let error) {
            throw APIError.networkError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
}
