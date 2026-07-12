import XCTest
@testable import MMD_Estoque

// MARK: - MockURLProtocol

/// Stub de URLSession: handlers por URL (ou contagem de chamadas).
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var requestCount = 0
    static var recordedRequests: [URLRequest] = []
    private static let lock = NSLock()

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        requestHandler = nil
        requestCount = 0
        recordedRequests = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.requestCount += 1
        Self.recordedRequests.append(request)
        let handler = Self.requestHandler
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}


// MARK: - Request body helper

private extension URLRequest {
    /// URLProtocol muitas vezes entrega o body só em `httpBodyStream`.
    var mmd_httpBodyData: Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read > 0 {
                data.append(buffer, count: read)
            } else {
                break
            }
        }
        return data
    }
}

// MARK: - AuthSessionStoreTests

final class AuthSessionStoreTests: XCTestCase {

    private var storage: InMemorySessionStore!
    private var session: URLSession!
    private var store: AuthSessionStore!

    private let baseURL = "https://example.supabase.co"
    private let anonKey = "test-anon-key"

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()

        storage = InMemorySessionStore()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)

        let url = baseURL
        let key = anonKey
        store = AuthSessionStore(
            storage: storage,
            urlSession: session,
            configProvider: { (url, key) }
        )
    }

    override func tearDown() {
        MockURLProtocol.reset()
        storage = nil
        session = nil
        store = nil
        super.tearDown()
    }

    // MARK: Helpers

    private func tokenJSON(
        access: String,
        refresh: String,
        expiresIn: Int,
        email: String = "supervisor@mmd.local"
    ) -> Data {
        """
        {
          "access_token": "\(access)",
          "refresh_token": "\(refresh)",
          "expires_in": \(expiresIn),
          "user": { "email": "\(email)" }
        }
        """.data(using: .utf8)!
    }

    private func httpResponse(url: URL, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    // MARK: 1. Login ok persiste e validAccessToken sem rede

    func testLoginPersistsSessionAndValidAccessTokenSkipsNetwork() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("grant_type=password") == true)
            let url = request.url!
            return (self.httpResponse(url: url, status: 200), self.tokenJSON(
                access: "access-1",
                refresh: "refresh-1",
                expiresIn: 3600
            ))
        }

        try await store.signIn(identifier: "supervisor", password: "secret")

        XCTAssertEqual(MockURLProtocol.requestCount, 1)
        let hasSession = await store.hasSession
        let email = await store.sessionEmail
        XCTAssertTrue(hasSession)
        XCTAssertEqual(email, "supervisor@mmd.local")

        // Persistiu no storage
        let data = try storage.load()
        XCTAssertNotNil(data)

        // validAccessToken sem rede (token ainda fresco)
        let before = MockURLProtocol.requestCount
        let token = try await store.validAccessToken()
        XCTAssertEqual(token, "access-1")
        XCTAssertEqual(MockURLProtocol.requestCount, before)
    }

    // MARK: 2. Token perto de expirar dispara refresh proativo

    func testValidAccessTokenRefreshesWhenNearExpiry() async throws {
        // Seed sessão quase expirada direto no storage
        let nearExpiry = AuthSessionStore.Session(
            accessToken: "old-access",
            refreshToken: "refresh-old",
            expiresAt: Date().addingTimeInterval(30), // < 120s
            userEmail: "user@mmd.local"
        )
        try storage.save(JSONEncoder().encode(nearExpiry))

        store = AuthSessionStore(
            storage: storage,
            urlSession: session,
            configProvider: { (self.baseURL, self.anonKey) }
        )

        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("grant_type=refresh_token") == true)
            let body = request.mmd_httpBodyData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            XCTAssertTrue(body.contains("refresh-old"))
            let url = request.url!
            return (self.httpResponse(url: url, status: 200), self.tokenJSON(
                access: "new-access",
                refresh: "refresh-new",
                expiresIn: 3600
            ))
        }

        let token = try await store.validAccessToken()
        XCTAssertEqual(token, "new-access")
        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }

    // MARK: 3. Single-flight: N concorrentes = 1 refresh

    func testSingleFlightRefreshOnConcurrentValidAccessToken() async throws {
        let expired = AuthSessionStore.Session(
            accessToken: "expired-access",
            refreshToken: "refresh-shared",
            expiresAt: Date().addingTimeInterval(-10),
            userEmail: "user@mmd.local"
        )
        try storage.save(JSONEncoder().encode(expired))

        store = AuthSessionStore(
            storage: storage,
            urlSession: session,
            configProvider: { (self.baseURL, self.anonKey) }
        )

        MockURLProtocol.requestHandler = { request in
            // Simula latência pra concorrência real
            Thread.sleep(forTimeInterval: 0.05)
            let url = request.url!
            return (self.httpResponse(url: url, status: 200), self.tokenJSON(
                access: "refreshed-once",
                refresh: "refresh-rotated",
                expiresIn: 3600
            ))
        }

        async let t1 = store.validAccessToken()
        async let t2 = store.validAccessToken()
        async let t3 = store.validAccessToken()
        async let t4 = store.validAccessToken()

        let tokens = try await [t1, t2, t3, t4]
        XCTAssertEqual(Set(tokens), ["refreshed-once"])
        XCTAssertEqual(MockURLProtocol.requestCount, 1, "single-flight deve gerar exatamente 1 refresh")
    }

    // MARK: 4. Refresh 400 → sessionExpired e sessão limpa

    func testRefresh400ClearsSessionAndThrowsSessionExpired() async throws {
        let expired = AuthSessionStore.Session(
            accessToken: "dead",
            refreshToken: "bad-refresh",
            expiresAt: Date().addingTimeInterval(-60),
            userEmail: "user@mmd.local"
        )
        try storage.save(JSONEncoder().encode(expired))

        store = AuthSessionStore(
            storage: storage,
            urlSession: session,
            configProvider: { (self.baseURL, self.anonKey) }
        )

        MockURLProtocol.requestHandler = { request in
            let url = request.url!
            return (self.httpResponse(url: url, status: 400), Data(#"{"error":"invalid_grant"}"#.utf8))
        }

        do {
            _ = try await store.refreshedAccessToken()
            XCTFail("Expected sessionExpired")
        } catch AuthError.sessionExpired {
            // ok
        } catch {
            XCTFail("Expected sessionExpired, got \(error)")
        }

        let hasSessionAfter = await store.hasSession
        XCTAssertFalse(hasSessionAfter)
        XCTAssertNil(try storage.load())
    }

    // MARK: 5. APIClient 401 → refresh → retry → sucesso

    @MainActor
    func testAPIClient401TriggersRefreshAndRetry() async throws {
        AppConfig.shared.save(
            supabaseUrl: baseURL,
            anonKey: anonKey,
            webApiUrl: "",
            webApiAuthToken: "",
            useMockRFID: true
        )

        let liveSession = AuthSessionStore.Session(
            accessToken: "stale-token",
            refreshToken: "refresh-ok",
            expiresAt: Date().addingTimeInterval(3600),
            userEmail: "user@mmd.local"
        )
        try storage.save(JSONEncoder().encode(liveSession))

        store = AuthSessionStore(
            storage: storage,
            urlSession: session,
            configProvider: { (self.baseURL, self.anonKey) }
        )

        var restCallCount = 0
        MockURLProtocol.requestHandler = { request in
            let url = request.url!
            let path = url.path

            if path.contains("/auth/v1/token") {
                return (self.httpResponse(url: url, status: 200), self.tokenJSON(
                    access: "fresh-token",
                    refresh: "refresh-2",
                    expiresIn: 3600
                ))
            }

            // PostgREST
            restCallCount += 1
            let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
            if restCallCount == 1 {
                XCTAssertTrue(auth.contains("stale-token"))
                return (self.httpResponse(url: url, status: 401), Data("unauthorized".utf8))
            }
            XCTAssertTrue(auth.contains("fresh-token"), "retry deve usar token novo")
            return (self.httpResponse(url: url, status: 200), Data("[]".utf8))
        }

        let client = APIClient(session: session, authStore: store)
        let items = try await client.fetchItems()
        XCTAssertTrue(items.isEmpty)
        XCTAssertEqual(restCallCount, 2)
    }

    // MARK: 6. APIClient sem sessão → sessionExpired (sem fallback anon)

    @MainActor
    func testAPIClientWithoutSessionThrowsSessionExpiredNoAnonFallback() async throws {
        AppConfig.shared.save(
            supabaseUrl: baseURL,
            anonKey: anonKey,
            webApiUrl: "",
            webApiAuthToken: "",
            useMockRFID: true
        )

        // storage vazio
        store = AuthSessionStore(
            storage: InMemorySessionStore(),
            urlSession: session,
            configProvider: { (self.baseURL, self.anonKey) }
        )

        MockURLProtocol.requestHandler = { _ in
            XCTFail("Não deve chamar rede sem sessão")
            throw URLError(.notConnectedToInternet)
        }

        let client = APIClient(session: session, authStore: store)

        do {
            _ = try await client.fetchItems()
            XCTFail("Expected sessionExpired")
        } catch let error as APIError {
            if case .sessionExpired = error {
                // ok
            } else {
                XCTFail("Expected sessionExpired, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(MockURLProtocol.requestCount, 0)
    }

    // MARK: 7. Migração limpa token manual em Release-path

    func testMigrationClearsManualTokenOnReleasePath() {
        let suite = "mmd.auth.migration.test.\(UUID().uuidString)"
        let ud = UserDefaults(suiteName: suite)!
        defer { ud.removePersistentDomain(forName: suite) }

        ud.set("eyJhbGciOi.manual.token", forKey: "mmd_web_api_auth_token")

        let cleared = AppConfig.applyLegacyManualAuthTokenMigration(
            isRelease: true,
            defaults: ud
        )
        XCTAssertTrue(cleared)
        XCTAssertNil(ud.string(forKey: "mmd_web_api_auth_token"))
        XCTAssertTrue(ud.bool(forKey: "mmd_cleared_manual_web_api_token_v1"))

        // Segunda chamada não limpa de novo (flag já setada)
        ud.set("another-token", forKey: "mmd_web_api_auth_token")
        let second = AppConfig.applyLegacyManualAuthTokenMigration(
            isRelease: true,
            defaults: ud
        )
        XCTAssertFalse(second)
        XCTAssertEqual(ud.string(forKey: "mmd_web_api_auth_token"), "another-token")

        // DEBUG path (isRelease false) não limpa
        let suite2 = "mmd.auth.migration.debug.\(UUID().uuidString)"
        let ud2 = UserDefaults(suiteName: suite2)!
        defer { ud2.removePersistentDomain(forName: suite2) }
        ud2.set("keep-me", forKey: "mmd_web_api_auth_token")
        let debug = AppConfig.applyLegacyManualAuthTokenMigration(
            isRelease: false,
            defaults: ud2
        )
        XCTAssertFalse(debug)
        XCTAssertEqual(ud2.string(forKey: "mmd_web_api_auth_token"), "keep-me")
    }

    // MARK: normalizeLoginIdentifier

    func testNormalizeLoginIdentifier() {
        XCTAssertEqual(AuthSessionStore.normalizeLoginIdentifier(" supervisor "), "supervisor@mmd.local")
        XCTAssertEqual(AuthSessionStore.normalizeLoginIdentifier("MARCELO@MMD.COM"), "marcelo@mmd.com")
        XCTAssertEqual(AuthSessionStore.normalizeLoginIdentifier(""), "")
    }
}
