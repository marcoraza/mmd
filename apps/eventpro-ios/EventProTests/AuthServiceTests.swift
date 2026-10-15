import XCTest
@testable import EventPro

@MainActor
final class AuthServiceTests: XCTestCase {

    private var savedSupabaseUrl = ""
    private var savedSupabaseKey = ""

    override func setUp() {
        super.setUp()
        savedSupabaseUrl = AppConfig.shared.supabaseUrl
        savedSupabaseKey = AppConfig.shared.supabaseAnonKey
        AppConfig.shared.clearSupabaseConfig()
    }

    override func tearDown() {
        AppConfig.shared.supabaseUrl = savedSupabaseUrl
        AppConfig.shared.supabaseAnonKey = savedSupabaseKey
        super.tearDown()
    }

    private func isolatedKeychain() -> KeychainStore {
        KeychainStore(service: "com.emdash.eventpro.tests.\(UUID().uuidString)")
    }

    // MARK: - Sessão

    func testSessaoExpiraComMargem() {
        let agora = Date()
        let sessao = AuthSession(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: agora.addingTimeInterval(30)
        )
        XCTAssertTrue(
            sessao.isExpired(now: agora),
            "Com margem de 60 s, uma sessão que vence em 30 s já conta como vencida"
        )
    }

    func testSessaoValidaNaoExpira() {
        let agora = Date()
        let sessao = AuthSession(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: agora.addingTimeInterval(3600)
        )
        XCTAssertFalse(sessao.isExpired(now: agora))
    }

    func testMargemDeRenovacaoEhUmMinuto() {
        XCTAssertEqual(AuthSession.refreshSkew, 60)
    }

    // MARK: - Estado inicial

    func testSemSessaoNaoEstaAutenticado() {
        let service = AuthService(keychain: isolatedKeychain())
        XCTAssertFalse(service.isAuthenticated)
        XCTAssertNil(service.session)
        XCTAssertNil(service.currentUserEmail)
    }

    func testValidAccessTokenSemSessaoLanca() async {
        let service = AuthService(keychain: isolatedKeychain())
        do {
            _ = try await service.validAccessToken()
            XCTFail("Esperava noSession")
        } catch let error as AuthError {
            XCTAssertEqual(error, .noSession)
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }
    }

    func testLoginSemSupabaseConfiguradoLanca() async {
        let service = AuthService(keychain: isolatedKeychain())
        do {
            try await service.signIn(email: "marcelo@mmd.com.br", password: "senha")
            XCTFail("Esperava notConfigured")
        } catch let error as AuthError {
            XCTAssertEqual(error, .notConfigured)
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }
    }

    func testLoginComCampoVazioLanca() async {
        AppConfig.shared.supabaseUrl = "https://exemplo.supabase.co"
        AppConfig.shared.supabaseAnonKey = "anon"

        let service = AuthService(keychain: isolatedKeychain())
        do {
            try await service.signIn(email: "   ", password: "")
            XCTFail("Esperava invalidCredentials")
        } catch let error as AuthError {
            XCTAssertEqual(error, .invalidCredentials)
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }
    }

    func testSignOutLimpaEstado() {
        let service = AuthService(keychain: isolatedKeychain())
        service.signOut()
        XCTAssertFalse(service.isAuthenticated)
        XCTAssertNil(service.lastError)
    }

    // MARK: - Mensagens

    func testMensagensDeErroSaoEmPortugues() {
        XCTAssertEqual(AuthError.invalidCredentials.errorDescription, "E-mail ou senha incorretos.")
        XCTAssertTrue(AuthError.noSession.errorDescription?.contains("Sessão expirada") ?? false)
        XCTAssertNotNil(AuthError.notConfigured.errorDescription)
        XCTAssertEqual(
            AuthError.server(status: 500, message: "boom").errorDescription,
            "boom"
        )
    }
}
