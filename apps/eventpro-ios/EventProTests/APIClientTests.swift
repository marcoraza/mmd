import XCTest
@testable import EventPro

@MainActor
final class APIClientTests: XCTestCase {

    private var savedSupabaseUrl = ""
    private var savedSupabaseKey = ""
    private var savedWebApiUrl = ""
    private var savedUseMockRFID = true

    override func setUp() {
        super.setUp()
        savedSupabaseUrl = AppConfig.shared.supabaseUrl
        savedSupabaseKey = AppConfig.shared.supabaseAnonKey
        savedWebApiUrl = AppConfig.shared.webApiUrl
        savedUseMockRFID = AppConfig.shared.useMockRFID

        AppConfig.shared.save(supabaseUrl: "", anonKey: "", webApiUrl: "", useMockRFID: savedUseMockRFID)
    }

    override func tearDown() {
        AppConfig.shared.save(
            supabaseUrl: savedSupabaseUrl,
            anonKey: savedSupabaseKey,
            webApiUrl: savedWebApiUrl,
            useMockRFID: savedUseMockRFID
        )
        super.tearDown()
    }

    // MARK: - Helpers

    /// Executa e devolve o erro, para o teste inspecionar o caso exato.
    private func capturarErro(_ operation: () async throws -> Void) async -> Error? {
        do {
            try await operation()
            return nil
        } catch {
            return error
        }
    }

    private func configurarEndpoints(webApi: String = "https://exemplo.vercel.app") {
        AppConfig.shared.save(
            supabaseUrl: "https://exemplo.supabase.co",
            anonKey: "anon-key-de-teste",
            webApiUrl: webApi,
            useMockRFID: true
        )
    }

    /// AuthService isolado num serviço de Keychain próprio por teste, para não
    /// encostar na sessão real do app nem em outro teste.
    private func authServiceSemSessao() -> AuthService {
        AuthService(keychain: KeychainStore(service: "com.emdash.eventpro.tests.\(UUID().uuidString)"))
    }

    // MARK: - Sem configuração de Supabase

    func testFetchItemsExigeSupabaseConfigurado() async {
        let erro = await capturarErro { _ = try await APIClient().fetchItems() }
        guard case .notConfigured? = erro as? APIError else {
            return XCTFail("Esperava notConfigured, veio \(String(describing: erro))")
        }
    }

    func testFetchProjectsExigeSupabaseConfigurado() async {
        let erro = await capturarErro { _ = try await APIClient().fetchProjects(status: [.confirmado]) }
        guard case .notConfigured? = erro as? APIError else {
            return XCTFail("Esperava notConfigured, veio \(String(describing: erro))")
        }
    }

    // MARK: - Sem configuração da Web API

    func testCheckoutExigeWebApiConfigurada() async {
        let erro = await capturarErro {
            _ = try await APIClient().checkoutProject(projectId: UUID(), metodoScan: .rfid)
        }
        guard case .webApiNotConfigured? = erro as? APIError else {
            return XCTFail("Esperava webApiNotConfigured, veio \(String(describing: erro))")
        }
    }

    func testRetornoExigeWebApiConfigurada() async {
        let erro = await capturarErro {
            _ = try await APIClient().returnProject(projectId: UUID(), metodoScan: .rfid, items: [])
        }
        guard case .webApiNotConfigured? = erro as? APIError else {
            return XCTFail("Esperava webApiNotConfigured, veio \(String(describing: erro))")
        }
    }

    func testResumoExigeWebApiConfigurada() async {
        let erro = await capturarErro {
            _ = try await APIClient().fetchEventoResumo(projectId: UUID())
        }
        guard case .webApiNotConfigured? = erro as? APIError else {
            return XCTFail("Esperava webApiNotConfigured, veio \(String(describing: erro))")
        }
    }

    func testConferenciaExigeWebApiConfigurada() async {
        let erro = await capturarErro {
            _ = try await APIClient().conferenciaRfid(
                projectId: UUID(),
                tags: ["E28011702000020A5C41B6E0"],
                contexto: .carregamento
            )
        }
        guard case .webApiNotConfigured? = erro as? APIError else {
            return XCTFail("Esperava webApiNotConfigured, veio \(String(describing: erro))")
        }
    }

    func testBuscaSeriaisExigeWebApiConfigurada() async {
        let erro = await capturarErro {
            _ = try await APIClient().buscaSeriais(SerialBuscaQuery(q: "beam 230"))
        }
        guard case .webApiNotConfigured? = erro as? APIError else {
            return XCTFail("Esperava webApiNotConfigured, veio \(String(describing: erro))")
        }
    }

    // MARK: - D3: sem credencial, não sai requisição

    func testWebApiRecusaChamadaSemSessao() async {
        configurarEndpoints()
        let client = APIClient(authService: authServiceSemSessao())

        let erro = await capturarErro {
            _ = try await client.checkoutProject(projectId: UUID(), metodoScan: .rfid)
        }

        guard case .naoAutenticado? = erro as? APIError else {
            return XCTFail("Esperava naoAutenticado, veio \(String(describing: erro))")
        }
    }

    func testWebApiSemAuthServiceTambemRecusa() async {
        configurarEndpoints()
        // Cliente sem AuthService nenhum: continua sem mandar requisição de
        // escrita sem credencial.
        let erro = await capturarErro {
            _ = try await APIClient().fetchEventoResumo(projectId: UUID())
        }
        guard case .naoAutenticado? = erro as? APIError else {
            return XCTFail("Esperava naoAutenticado, veio \(String(describing: erro))")
        }
    }

    // MARK: - D2: normalização antes de sair

    func testRecordRfidScansRecusaTagInvalida() async {
        configurarEndpoints()
        let erro = await capturarErro {
            _ = try await APIClient().recordRfidScans(tags: ["curta"], contexto: .inventario)
        }
        guard case .tagsInvalidas? = erro as? APIError else {
            return XCTFail("Esperava tagsInvalidas, veio \(String(describing: erro))")
        }
    }

    func testRecordRfidScansSemTagsNaoChamaRede() async throws {
        configurarEndpoints()
        let response = try await APIClient().recordRfidScans(tags: [], contexto: .inventario)
        XCTAssertTrue(response.resolved.isEmpty)
        XCTAssertTrue(response.unresolved.isEmpty)
        XCTAssertTrue(response.scanIds.isEmpty)
    }

    func testConferenciaRecusaLoteVazio() async {
        configurarEndpoints()
        let erro = await capturarErro {
            _ = try await APIClient().conferenciaRfid(projectId: UUID(), tags: [], contexto: .conferencia)
        }
        guard case .parametrosInvalidos? = erro as? APIError else {
            return XCTFail("Esperava parametrosInvalidos, veio \(String(describing: erro))")
        }
    }

    func testBuscaSeriaisRecusaTermoComCaractereProibido() async {
        configurarEndpoints()
        let erro = await capturarErro {
            _ = try await APIClient().buscaSeriais(SerialBuscaQuery(q: "beam,230"))
        }
        guard case .parametrosInvalidos? = erro as? APIError else {
            return XCTFail("Esperava parametrosInvalidos, veio \(String(describing: erro))")
        }
    }

    // MARK: - Vínculo de tag (POST /api/rfid/vinculo)

    func testLinkTagExigeWebApiConfigurada() async {
        let erro = await capturarErro {
            try await APIClient().linkTag(serialId: UUID(), tagRfid: "E28011702000020A5C41B6E0")
        }
        guard case .webApiNotConfigured? = erro as? APIError else {
            return XCTFail("Esperava webApiNotConfigured, veio \(String(describing: erro))")
        }
    }

    func testLinkTagRecusaTagInvalidaAntesDeTudo() async {
        let erro = await capturarErro {
            try await APIClient().linkTag(serialId: UUID(), tagRfid: "xx")
        }
        guard case .tagsInvalidas? = erro as? APIError else {
            return XCTFail("Esperava tagsInvalidas, veio \(String(describing: erro))")
        }
    }

    // MARK: - Entradas vazias

    func testFetchSerialsByIdsRetornaVazioParaEntradaVazia() async throws {
        let result = try await APIClient().fetchSerialsByIds([])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - D9: id em minúsculas na saída

    func testPathIdNormalizaParaMinusculas() {
        let id = UUID(uuidString: "1F2B7C1E-4A63-4F0E-9D70-9C2A1F9F1A01")!
        XCTAssertEqual(APIClient.pathId(id), "1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01")
    }

    // MARK: - Sanitização de código

    func testSanitizedLookupCodeAceitaCodigoInterno() {
        XCTAssertEqual(APIClient.sanitizedLookupCode(" MMD-ILU-0001 "), "MMD-ILU-0001")
    }

    func testSanitizedLookupCodeRecusaInjecaoDeFiltro() {
        XCTAssertNil(APIClient.sanitizedLookupCode("MMD-ILU-0001,MMD-ILU-0002"))
        XCTAssertNil(APIClient.sanitizedLookupCode("in.(\"a\",\"b\")"))
        XCTAssertNil(APIClient.sanitizedLookupCode("*"))
        XCTAssertNil(APIClient.sanitizedLookupCode(""))
    }

    // MARK: - Descrições de erro

    func testAPIErrorDescriptions() {
        XCTAssertNotNil(APIError.invalidURL.errorDescription)
        XCTAssertNotNil(APIError.notConfigured.errorDescription)
        XCTAssertNotNil(APIError.webApiNotConfigured.errorDescription)
        XCTAssertNotNil(APIError.naoAutenticado.errorDescription)
        XCTAssertTrue(APIError.httpError(statusCode: 404, body: nil).errorDescription!.contains("404"))
        XCTAssertTrue(APIError.tagsInvalidas(["curta"]).errorDescription!.contains("curta"))
        XCTAssertTrue(
            APIError.endpointPendente(nome: "Vínculo", detalhe: "falta contrato")
                .errorDescription!
                .contains("Vínculo")
        )
    }
}
