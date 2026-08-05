import Foundation
import os.log

// MARK: - APIError

enum APIError: LocalizedError {
    case invalidURL
    case notConfigured
    case webApiNotConfigured
    case naoAutenticado
    case parametrosInvalidos(String)
    case tagsInvalidas([String])
    case endpointPendente(nome: String, detalhe: String)
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
        case .naoAutenticado:
            return "Sessao expirada. Faca login novamente."
        case .parametrosInvalidos(let detalhe):
            return "Parametros invalidos: \(detalhe)"
        case .tagsInvalidas(let tags):
            let amostra = tags.prefix(3).joined(separator: ", ")
            return "Tag RFID fora do formato aceito (\(tags.count)): \(amostra)"
        case .endpointPendente(let nome, let detalhe):
            return "\(nome) ainda nao existe na API. \(detalhe)"
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

/// Cliente HTTP do EventPro.
///
/// Duas superfícies, com fronteiras diferentes:
/// - **Web API (`/api/*`)**: toda mutação operacional. Check-out, retorno,
///   telemetria de scan, conferência RFID. Contratos congelados em
///   `docs/contratos-api.md`.
/// - **PostgREST (`/rest/v1/*`)**: só leitura de catálogo, packing e
///   movimentações, enquanto não houver endpoint de leitura equivalente.
///
/// Os caminhos legados de **escrita** direta no PostgREST
/// (`registerCheckout`, `registerReturn`, `linkTag` por PATCH,
/// `updateProjectStatus`) foram removidos: nenhum cliente escreve no banco.
@MainActor
final class APIClient: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isLoading = false
    @Published var lastError: APIError?

    // MARK: - Dependências

    private let session: URLSession
    private let authService: AuthService?
    private let logger = Logger(subsystem: "com.emdash.eventpro", category: "APIClient")

    private var baseURL: String { AppConfig.shared.supabaseUrl }
    private var apiKey: String { AppConfig.shared.supabaseAnonKey }
    private var webApiBaseURL: String { AppConfig.shared.webApiUrl }

    // MARK: - Datas

    /// Postgres devolve ISO 8601 com fração de segundo e fuso,
    /// ex.: "2026-03-20T14:30:00.000000+00:00". Nem toda coluna tem fração.
    private static let dateFormatterWithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let dateFormatterPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Decoder compartilhado. **Sem** `.convertFromSnakeCase`: cada modelo
    /// declara seus `CodingKeys`, e o contrato manda no nome da chave.
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = dateFormatterWithFraction.date(from: string) { return date }
            if let date = dateFormatterPlain.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Data nao reconhecida: \(string)"
            )
        }
        return decoder
    }

    private lazy var decoder: JSONDecoder = APIClient.makeDecoder()
    private lazy var encoder = JSONEncoder()

    // MARK: - Init

    init(session: URLSession = .shared, authService: AuthService? = nil) {
        self.session = session
        self.authService = authService
    }

    // MARK: - Check-out
    //
    // POST /api/eventos/{id}/checkout — contratos-api.md seção 2.

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
            path: "/api/eventos/\(Self.pathId(projectId))/checkout",
            method: "POST",
            body: body
        )
        return try await perform(request)
    }

    // MARK: - Retorno
    //
    // POST /api/eventos/{id}/retorno — contratos-api.md seção 3.
    // A RPC exige cobertura total do conjunto EM_CAMPO do evento: item não
    // conferido precisa chegar como NAO_VOLTOU, nunca omitido (divergência D1).

    func returnProject(
        projectId: UUID,
        metodoScan: MetodoScan,
        items: [ReturnProjectItemRequest]
    ) async throws -> ReturnProjectResponse {
        let body = try encoder.encode(
            ReturnProjectRequest(metodo: metodoScan.rawValue, items: items)
        )
        let request = try await makeWebApiRequest(
            path: "/api/eventos/\(Self.pathId(projectId))/retorno",
            method: "POST",
            body: body
        )
        return try await perform(request)
    }

    // MARK: - Resumo do evento
    //
    // GET /api/eventos/{id}/resumo — contratos-api.md seção 4.
    // O app legado nunca chamava: agregava tudo client-side.

    func fetchEventoResumo(projectId: UUID) async throws -> EventoResumo {
        let request = try await makeWebApiRequest(
            path: "/api/eventos/\(Self.pathId(projectId))/resumo"
        )
        return try await perform(request)
    }

    // MARK: - Telemetria de scan
    //
    // POST /api/rfid/scans — contratos-api.md seção 5.

    /// Grava um lote de leituras. As tags são normalizadas **no cliente** com a
    /// mesma regra do servidor (divergência D2): assim o casamento contra
    /// `resolved[].tag_rfid` e `unresolved[]` é exato.
    ///
    /// Uma tag inválida derruba o lote inteiro no servidor (`tags_invalidas`),
    /// então as inválidas são recusadas aqui, antes da chamada.
    @discardableResult
    func recordRfidScans(
        tags: [String],
        contexto: RfidScanContext,
        projectId: UUID? = nil,
        reader: RfidScanReaderRequest? = nil,
        localizacao: String? = nil,
        rssiPorTag: [String: Int]? = nil
    ) async throws -> RfidScanResponse {
        let (validas, invalidas) = RfidTagNormalizer.normalizeBatch(tags)

        guard invalidas.isEmpty else {
            throw APIError.tagsInvalidas(invalidas)
        }
        guard !validas.isEmpty else {
            return RfidScanResponse(resolved: [], unresolved: [], scanIds: [])
        }

        let body = try encoder.encode(
            RfidScanRequest(
                tags: validas,
                contexto: contexto,
                projetoId: projectId,
                reader: reader,
                localizacao: localizacao,
                rssiPorTag: rssiPorTag.map { mapa in
                    // Reindexa pelo EPC normalizado: a chave precisa casar com
                    // a tag enviada, não com a leitura crua do SDK.
                    Dictionary(
                        mapa.compactMap { key, value in
                            RfidTagNormalizer.normalizeIfValid(key).map { ($0, value) }
                        },
                        uniquingKeysWith: { current, _ in current }
                    )
                }
            )
        )

        let request = try await makeWebApiRequest(path: "/api/rfid/scans", method: "POST", body: body)
        return try await perform(request)
    }

    /// Grava o lote e devolve os itens resolvidos com item pai, para as telas
    /// que precisam casar com o packing list.
    func recordAndResolveRfidTags(
        tags: [String],
        contexto: RfidScanContext,
        projectId: UUID? = nil,
        reader: RfidScanReaderRequest? = nil,
        rssiPorTag: [String: Int]? = nil
    ) async throws -> (resolved: [ResolvedItem], unresolved: [String]) {
        let scan = try await recordRfidScans(
            tags: tags,
            contexto: contexto,
            projectId: projectId,
            reader: reader,
            rssiPorTag: rssiPorTag
        )

        guard !scan.resolved.isEmpty else {
            return (resolved: [], unresolved: scan.unresolved)
        }

        let serials = try await fetchSerialsByIds(scan.resolved.map(\.serialId))
        let serialsById = Dictionary(serials.map { ($0.id, $0) }, uniquingKeysWith: { current, _ in current })

        var resolved: [ResolvedItem] = []
        var unresolved = scan.unresolved

        for match in scan.resolved {
            guard let serial = serialsById[match.serialId], let equipment = serial.item else {
                unresolved.append(match.tagRfid)
                continue
            }
            resolved.append(
                ResolvedItem(
                    serialNumber: serial,
                    equipment: equipment,
                    rssi: rssiPorTag?[match.tagRfid]
                )
            )
        }

        return (resolved: resolved, unresolved: unresolved)
    }

    // MARK: - Conferência RFID
    //
    // POST /api/eventos/{id}/conferencia-rfid — contratos-api.md seção 7.
    // Fecha o loop RFID x operação: tags lidas contra seriais alocados.
    // Não muta status: conferência é leitura mais telemetria.

    func conferenciaRfid(
        projectId: UUID,
        tags: [String],
        contexto: ConferenciaContexto,
        reader: RfidScanReaderRequest? = nil,
        localizacao: String? = nil
    ) async throws -> ConferenciaRfidResponse {
        let (validas, invalidas) = RfidTagNormalizer.normalizeBatch(tags)

        guard invalidas.isEmpty else {
            throw APIError.tagsInvalidas(invalidas)
        }
        guard !validas.isEmpty else {
            throw APIError.parametrosInvalidos("nenhuma tag lida para conferir")
        }

        let body = try encoder.encode(
            ConferenciaRfidRequest(
                tags: validas,
                contexto: contexto,
                reader: reader,
                localizacao: localizacao
            )
        )
        let request = try await makeWebApiRequest(
            path: "/api/eventos/\(Self.pathId(projectId))/conferencia-rfid",
            method: "POST",
            body: body
        )
        return try await perform(request)
    }

    // MARK: - Busca de seriais
    //
    // GET /api/seriais/busca — contratos-api.md seção 8.
    // Substitui a busca client-side do legado, que baixava o catálogo inteiro.

    func buscaSeriais(_ query: SerialBuscaQuery) async throws -> SerialBuscaResponse {
        guard query.isTermValid else {
            throw APIError.parametrosInvalidos(
                "termo de busca precisa ter de \(SerialBuscaQuery.minQueryLength) a \(SerialBuscaQuery.maxQueryLength) caracteres, sem virgula, parenteses, aspas ou asterisco"
            )
        }
        let request = try await makeWebApiRequest(
            path: "/api/seriais/busca",
            queryItems: query.queryItems
        )
        return try await perform(request)
    }

    // MARK: - Vínculo de tag
    //
    // POST /api/rfid/vinculo, endpoint que fecha o gap 4.2 da auditoria.
    // O caminho legado (PATCH direto em `serial_numbers` pelo PostgREST) segue
    // aposentado: nenhum cliente escreve no banco.

    struct LinkTagRequest: Encodable {
        let serial_id: String
        let tag: String
    }

    struct LinkTagResponse: Decodable {
        let codigo_interno: String
        let tag_rfid: String
    }

    @discardableResult
    func linkTag(serialId: UUID, tagRfid: String) async throws -> LinkTagResponse {
        guard let tag = RfidTagNormalizer.normalizeIfValid(tagRfid) else {
            throw APIError.tagsInvalidas([tagRfid])
        }
        let body = try encoder.encode(LinkTagRequest(serial_id: Self.pathId(serialId), tag: tag))
        let request = try await makeWebApiRequest(
            path: "/api/rfid/vinculo",
            method: "POST",
            body: body
        )
        return try await perform(request)
    }

    // MARK: - Leituras (PostgREST)

    /// Catálogo de itens, ordenado por nome.
    func fetchItems() async throws -> [Equipment] {
        let request = try await makeSupabaseRequest(
            path: "/rest/v1/items",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "nome.asc"),
            ]
        )
        return try await perform(request)
    }

    func fetchSerialNumbers(forItemId id: UUID) async throws -> [SerialNumber] {
        let request = try await makeSupabaseRequest(
            path: "/rest/v1/serial_numbers",
            queryItems: [
                URLQueryItem(name: "item_id", value: "eq.\(Self.pathId(id))"),
                URLQueryItem(name: "select", value: "*"),
            ]
        )
        return try await perform(request)
    }

    func fetchProjects(status: [StatusProjeto]) async throws -> [Project] {
        let statusValues = status.map { "\"\($0.rawValue)\"" }.joined(separator: ",")
        let request = try await makeSupabaseRequest(
            path: "/rest/v1/projetos",
            queryItems: [
                URLQueryItem(name: "status", value: "in.(\(statusValues))"),
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "data_inicio.asc"),
            ]
        )
        return try await perform(request)
    }

    func fetchPackingList(projectId: UUID) async throws -> [PackingListItem] {
        let request = try await makeSupabaseRequest(
            path: "/rest/v1/packing_list",
            queryItems: [
                URLQueryItem(name: "projeto_id", value: "eq.\(Self.pathId(projectId))"),
                URLQueryItem(name: "select", value: "*,item:items(*)"),
            ]
        )
        return try await perform(request)
    }

    func fetchProjectMovements(projectId: UUID, tipo: TipoMovimentacao? = nil) async throws -> [Movement] {
        var queryItems = [
            URLQueryItem(name: "projeto_id", value: "eq.\(Self.pathId(projectId))"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "timestamp.desc"),
        ]
        if let tipo {
            queryItems.append(URLQueryItem(name: "tipo", value: "eq.\(tipo.rawValue)"))
        }
        let request = try await makeSupabaseRequest(path: "/rest/v1/movimentacoes", queryItems: queryItems)
        return try await perform(request)
    }

    /// Resolve um QR para o serial com o item pai.
    func resolveQRCode(_ code: String) async throws -> SerialNumber? {
        guard let sanitized = Self.sanitizedLookupCode(code) else {
            throw APIError.parametrosInvalidos("código QR fora do formato aceito")
        }
        let request = try await makeSupabaseRequest(
            path: "/rest/v1/serial_numbers",
            queryItems: [
                URLQueryItem(name: "qr_code", value: "eq.\(sanitized)"),
                URLQueryItem(name: "select", value: "*,item:items(*)"),
            ]
        )
        let results: [SerialNumber] = try await perform(request)
        return results.first
    }

    func fetchSerialsByIds(_ ids: [UUID]) async throws -> [SerialNumber] {
        guard !ids.isEmpty else { return [] }
        let quoted = ids.map { "\"\(Self.pathId($0))\"" }.joined(separator: ",")
        let request = try await makeSupabaseRequest(
            path: "/rest/v1/serial_numbers",
            queryItems: [
                URLQueryItem(name: "id", value: "in.(\(quoted))"),
                URLQueryItem(name: "select", value: "*,item:items(*)"),
            ]
        )
        return try await perform(request)
    }

    // MARK: - Requests

    /// Ids do Swift saem em maiúsculas (`UUID.uuidString`). O Postgres aceita
    /// uuid sem ligar para caixa, mas comparação textual no BFF, chave de mapa
    /// e cache, não (divergência D9). Normaliza na saída.
    static func pathId(_ id: UUID) -> String {
        id.uuidString.lowercased()
    }

    /// Sanitização anti-injeção de filtro PostgREST: sem vírgula, parêntese,
    /// aspas ou `*`, no mesmo espírito de `normalizeInternalQrLookupCode`.
    static func sanitizedLookupCode(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 128 else { return nil }
        var allowed = CharacterSet.alphanumerics
        allowed.formUnion(CharacterSet(charactersIn: "._:-/"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return trimmed
    }

    private func bearerToken() async throws -> String? {
        guard let authService else { return nil }
        do {
            return try await authService.validAccessToken()
        } catch AuthError.noSession {
            return nil
        } catch {
            throw APIError.naoAutenticado
        }
    }

    /// Requisição para o PostgREST do Supabase (somente leitura).
    private func makeSupabaseRequest(
        path: String,
        queryItems: [URLQueryItem] = [],
        method: String = "GET"
    ) async throws -> URLRequest {
        guard !baseURL.isEmpty, !apiKey.isEmpty else {
            throw APIError.notConfigured
        }

        guard var components = URLComponents(string: AppConfig.sanitizedBase(baseURL) + path) else {
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Token do usuário quando houver sessão; senão a anon key, que é o que
        // a RLS de leitura pública espera.
        let token = (try await bearerToken()) ?? apiKey
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return request
    }

    /// Requisição para a Web API (`/api/*`).
    ///
    /// **Sem token, não sai requisição.** O legado mandava sem `Authorization`
    /// e degradava para cookie SSR, que do iOS não existe; pior, num ambiente
    /// com `MMD_REQUIRE_AUTH` desligada isso executava check-out real como admin
    /// anônimo (divergência D3, risco 5.2 da auditoria).
    private func makeWebApiRequest(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> URLRequest {
        guard !webApiBaseURL.isEmpty else {
            throw APIError.webApiNotConfigured
        }

        guard var components = URLComponents(string: AppConfig.sanitizedBase(webApiBaseURL) + path) else {
            throw APIError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        guard let token = try await bearerToken(), !token.isEmpty else {
            throw APIError.naoAutenticado
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        return request
    }

    // MARK: - Execução

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

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError: APIError
            if httpResponse.statusCode == 401 {
                apiError = .naoAutenticado
            } else {
                apiError = .httpError(
                    statusCode: httpResponse.statusCode,
                    body: Self.errorMessage(from: data)
                )
            }
            lastError = apiError
            throw apiError
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let apiError = APIError.decodingError(error)
            lastError = apiError
            #if DEBUG
            logger.error("Falha de decode: \(String(describing: error))")
            #endif
            throw apiError
        }
    }

    /// Toda a superfície devolve `{"error": "..."}`. O valor tem dois formatos
    /// convivendo (código snake_case e frase em pt-BR) e os dois são úteis para
    /// o operador; nenhum dos dois vira `switch` no cliente.
    private struct ErrorEnvelope: Decodable {
        let error: String
    }

    private static func errorMessage(from data: Data) -> String? {
        if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            return envelope.error
        }
        guard let raw = String(data: data, encoding: .utf8), !raw.isEmpty else { return nil }
        return String(raw.prefix(240))
    }
}
