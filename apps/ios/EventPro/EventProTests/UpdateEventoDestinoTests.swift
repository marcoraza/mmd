import XCTest
@testable import EventPro

@MainActor
final class UpdateEventoDestinoTests: XCTestCase {

    private var savedSupabaseUrl = ""
    private var savedSupabaseKey = ""
    private var savedWebApiUrl = ""
    private var savedWebApiAuthToken = ""
    private var savedUseMockRFID = true

    private var mockSession: URLSession!
    private var authStore: AuthSessionStore!
    private var client: APIClient!

    private let baseURL = "https://example.supabase.co"
    private let anonKey = "test-anon-key"
    private let accessToken = "test-access-token"

    override func setUp() async throws {
        try await super.setUp()
        MockURLProtocol.reset()

        savedSupabaseUrl = AppConfig.shared.supabaseUrl
        savedSupabaseKey = AppConfig.shared.supabaseAnonKey
        savedWebApiUrl = AppConfig.shared.webApiUrl
        savedWebApiAuthToken = AppConfig.shared.webApiAuthToken
        savedUseMockRFID = AppConfig.shared.useMockRFID

        AppConfig.shared.save(
            supabaseUrl: baseURL,
            anonKey: anonKey,
            webApiUrl: "",
            webApiAuthToken: "",
            useMockRFID: true
        )

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)

        let storage = InMemorySessionStore()
        let live = AuthSessionStore.Session(
            accessToken: accessToken,
            refreshToken: "test-refresh",
            expiresAt: Date().addingTimeInterval(3600),
            userEmail: "editor@mmd.local"
        )
        try storage.save(JSONEncoder().encode(live))

        let url = baseURL
        let key = anonKey
        authStore = AuthSessionStore(
            storage: storage,
            urlSession: mockSession,
            configProvider: { (url, key) }
        )

        let authState = AuthState(store: authStore, restoreOnInit: false)
        await authState.restore()
        client = APIClient(session: mockSession, authState: authState)
    }

    override func tearDown() async throws {
        AppConfig.shared.save(
            supabaseUrl: savedSupabaseUrl,
            anonKey: savedSupabaseKey,
            webApiUrl: savedWebApiUrl,
            webApiAuthToken: savedWebApiAuthToken,
            useMockRFID: savedUseMockRFID
        )
        MockURLProtocol.reset()
        try await super.tearDown()
    }

    func testUpdateEventoDestinoSendsMinimalPayloadAndAuth() async throws {
        let projectId = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let known = Date(timeIntervalSince1970: 1_785_672_000)
        let expectedTimestamp: String = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.string(from: known)
        }()

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.url?.path, "/rest/v1/projetos")
            XCTAssertTrue(
                request.url?.query?.contains("id=eq.\(projectId.uuidString)") == true
                    || request.url?.absoluteString.contains("id=eq.\(projectId.uuidString)") == true
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), self.anonKey)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(self.accessToken)")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "return=minimal")

            let body = try XCTUnwrap(request.mmd_httpBodyData)
            let json = try XCTUnwrap(
                try JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            let keys = Set(json.keys)
            XCTAssertEqual(
                keys,
                Set(["destino_latitude", "destino_longitude", "destino_confirmado_em"]),
                "payload deve conter somente os campos do destino"
            )
            XCTAssertEqual(json["destino_latitude"] as? Double, -23.561414)
            XCTAssertEqual(json["destino_longitude"] as? Double, -46.655881)
            XCTAssertEqual(json["destino_confirmado_em"] as? String, expectedTimestamp)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        try await client.updateEventoDestino(
            projectId: projectId,
            latitude: -23.561414,
            longitude: -46.655881,
            confirmadoEm: known
        )

        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }

    func testClearEventoDestinoSendsExplicitNulls() async throws {
        let projectId = UUID()

        MockURLProtocol.requestHandler = { request in
            let body = try XCTUnwrap(request.mmd_httpBodyData)
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertTrue(json?["destino_latitude"] is NSNull)
            XCTAssertTrue(json?["destino_longitude"] is NSNull)
            XCTAssertTrue(json?["destino_confirmado_em"] is NSNull)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        try await client.updateEventoDestino(
            projectId: projectId,
            latitude: nil,
            longitude: nil
        )

        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }

    func testIncompletePairIsRejectedWithoutNetwork() async {
        MockURLProtocol.requestHandler = { _ in
            XCTFail("par incompleto não deve chamar a rede")
            throw URLError(.badServerResponse)
        }

        do {
            try await client.updateEventoDestino(
                projectId: UUID(),
                latitude: -23.5,
                longitude: nil
            )
            XCTFail("esperava erro de par incompleto")
        } catch let error as APIError {
            if case .invalidRequest = error {
                // expected
            } else {
                XCTFail("esperava invalidRequest, got \(error)")
            }
        } catch {
            XCTFail("tipo inesperado: \(error)")
        }

        XCTAssertEqual(MockURLProtocol.requestCount, 0)
    }

    func testOutOfRangeCoordinatesRejectedWithoutNetwork() async {
        do {
            try await client.updateEventoDestino(
                projectId: UUID(),
                latitude: 91,
                longitude: 0
            )
            XCTFail("esperava erro de faixa")
        } catch let error as APIError {
            if case .invalidRequest = error {
                // expected
            } else {
                XCTFail("esperava invalidRequest, got \(error)")
            }
        } catch {
            XCTFail("tipo inesperado: \(error)")
        }

        XCTAssertEqual(MockURLProtocol.requestCount, 0)
    }
}

@MainActor
final class AuthCoordinationTests: XCTestCase {

    private let baseURL = "https://example.supabase.co"
    private let anonKey = "test-anon-key"
    private let email = "editor@mmd.local"

    private var savedSupabaseUrl = ""
    private var savedSupabaseKey = ""
    private var savedWebApiUrl = ""
    private var savedWebApiAuthToken = ""
    private var savedUseMockRFID = true
    private var mockSession: URLSession!

    override func setUp() async throws {
        try await super.setUp()
        MockURLProtocol.reset()

        savedSupabaseUrl = AppConfig.shared.supabaseUrl
        savedSupabaseKey = AppConfig.shared.supabaseAnonKey
        savedWebApiUrl = AppConfig.shared.webApiUrl
        savedWebApiAuthToken = AppConfig.shared.webApiAuthToken
        savedUseMockRFID = AppConfig.shared.useMockRFID

        AppConfig.shared.save(
            supabaseUrl: baseURL,
            anonKey: anonKey,
            webApiUrl: "",
            webApiAuthToken: "",
            useMockRFID: true
        )

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
    }

    override func tearDown() async throws {
        AppConfig.shared.save(
            supabaseUrl: savedSupabaseUrl,
            anonKey: savedSupabaseKey,
            webApiUrl: savedWebApiUrl,
            webApiAuthToken: savedWebApiAuthToken,
            useMockRFID: savedUseMockRFID
        )
        MockURLProtocol.reset()
        try await super.tearDown()
    }

    func testRestoreKeepsGateNeutralUntilStoredSessionIsKnown() async throws {
        let (_, auth) = try makeSignedInAuth()

        XCTAssertEqual(auth.state, .restoring)

        await auth.restore()

        XCTAssertEqual(auth.state, .signedIn(email: email))
    }

    func testRestoreWithoutSessionOpensLogin() async {
        let store = AuthSessionStore(
            storage: InMemorySessionStore(),
            urlSession: mockSession,
            configProvider: { (self.baseURL, self.anonKey) }
        )
        let auth = AuthState(store: store, restoreOnInit: false)

        XCTAssertEqual(auth.state, .restoring)

        await auth.restore()

        XCTAssertEqual(auth.state, .signedOut)
    }

    func testFirst401RefreshesAndKeepsCanonicalSession() async throws {
        let (_, auth) = try makeSignedInAuth()
        await auth.restore()
        let client = APIClient(session: mockSession, authState: auth)

        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/auth/v1/token" {
                return Self.response(
                    request,
                    status: 200,
                    body: Self.refreshBody(email: self.email)
                )
            }

            if request.value(forHTTPHeaderField: "Authorization") == "Bearer refreshed-access" {
                return Self.response(request, status: 204)
            }

            return Self.response(request, status: 401)
        }

        try await client.updateEventoDestino(
            projectId: UUID(),
            latitude: -23.561414,
            longitude: -46.655881
        )

        XCTAssertEqual(auth.state, .signedIn(email: email))
    }

    func testSecond401ClearsCanonicalSessionAndStoredSession() async throws {
        let (store, auth) = try makeSignedInAuth()
        await auth.restore()
        let client = APIClient(session: mockSession, authState: auth)

        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/auth/v1/token" {
                return Self.response(
                    request,
                    status: 200,
                    body: Self.refreshBody(email: self.email)
                )
            }
            return Self.response(request, status: 401)
        }

        await assertSessionExpired {
            try await client.updateEventoDestino(
                projectId: UUID(),
                latitude: -23.561414,
                longitude: -46.655881
            )
        }

        XCTAssertEqual(auth.state, .signedOut)
        let hasSession = await store.hasSession
        XCTAssertFalse(hasSession)
    }

    func testReadRefreshesAfterFirst401AndKeepsCanonicalSession() async throws {
        let (_, auth) = try makeSignedInAuth()
        await auth.restore()
        let client = APIClient(session: mockSession, authState: auth)

        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/auth/v1/token" {
                return Self.response(
                    request,
                    status: 200,
                    body: Self.refreshBody(email: self.email)
                )
            }

            if request.value(forHTTPHeaderField: "Authorization") == "Bearer refreshed-access" {
                return Self.response(request, status: 200, body: Data("[]".utf8))
            }

            return Self.response(request, status: 401)
        }

        let projects = try await client.fetchProjects(status: [.confirmado])

        XCTAssertTrue(projects.isEmpty)
        XCTAssertEqual(auth.state, .signedIn(email: email))
    }

    func testSecond401OnReadClearsCanonicalSessionAndStoredSession() async throws {
        let (store, auth) = try makeSignedInAuth()
        await auth.restore()
        let client = APIClient(session: mockSession, authState: auth)

        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/auth/v1/token" {
                return Self.response(
                    request,
                    status: 200,
                    body: Self.refreshBody(email: self.email)
                )
            }
            return Self.response(request, status: 401)
        }

        await assertSessionExpired {
            _ = try await client.fetchProjects(status: [.confirmado])
        }

        XCTAssertEqual(auth.state, .signedOut)
        let hasSession = await store.hasSession
        XCTAssertFalse(hasSession)
    }

    func testRejectedRefreshClearsCanonicalSession() async throws {
        let (store, auth) = try makeSignedInAuth()
        await auth.restore()
        let client = APIClient(session: mockSession, authState: auth)

        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/auth/v1/token" {
                return Self.response(request, status: 400)
            }
            return Self.response(request, status: 401)
        }

        await assertSessionExpired {
            try await client.updateEventoDestino(
                projectId: UUID(),
                latitude: -23.561414,
                longitude: -46.655881
            )
        }

        XCTAssertEqual(auth.state, .signedOut)
        let hasSession = await store.hasSession
        XCTAssertFalse(hasSession)
    }

    func testOfflineAndTimeoutPreserveCanonicalSession() async throws {
        for code in [URLError.notConnectedToInternet, URLError.timedOut] {
            MockURLProtocol.reset()
            let (store, auth) = try makeSignedInAuth()
            await auth.restore()
            let client = APIClient(session: mockSession, authState: auth)
            MockURLProtocol.requestHandler = { _ in throw URLError(code) }

            do {
                try await client.updateEventoDestino(
                    projectId: UUID(),
                    latitude: -23.561414,
                    longitude: -46.655881
                )
                XCTFail("esperava falha de rede para \(code)")
            } catch let error as APIError {
                guard case .networkError = error else {
                    return XCTFail("esperava networkError, recebeu \(error)")
                }
            }

            XCTAssertEqual(auth.state, .signedIn(email: email))
            let hasSession = await store.hasSession
            XCTAssertTrue(hasSession)
        }
    }

    func testForbiddenAndServerFailurePreserveCanonicalSession() async throws {
        for status in [403, 500] {
            MockURLProtocol.reset()
            let (store, auth) = try makeSignedInAuth()
            await auth.restore()
            let client = APIClient(session: mockSession, authState: auth)
            MockURLProtocol.requestHandler = { request in
                Self.response(request, status: status)
            }

            do {
                try await client.updateEventoDestino(
                    projectId: UUID(),
                    latitude: -23.561414,
                    longitude: -46.655881
                )
                XCTFail("esperava HTTP \(status)")
            } catch let error as APIError {
                guard case .httpError(let received, _) = error else {
                    return XCTFail("esperava httpError, recebeu \(error)")
                }
                XCTAssertEqual(received, status)
            }

            XCTAssertEqual(auth.state, .signedIn(email: email))
            let hasSession = await store.hasSession
            XCTAssertTrue(hasSession)
        }
    }

    private func makeSignedInAuth() throws -> (AuthSessionStore, AuthState) {
        let storage = InMemorySessionStore()
        let session = AuthSessionStore.Session(
            accessToken: "original-access",
            refreshToken: "original-refresh",
            expiresAt: Date().addingTimeInterval(3600),
            userEmail: email
        )
        try storage.save(JSONEncoder().encode(session))

        let store = AuthSessionStore(
            storage: storage,
            urlSession: mockSession,
            configProvider: { (self.baseURL, self.anonKey) }
        )
        return (store, AuthState(store: store, restoreOnInit: false))
    }

    private func assertSessionExpired(
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("esperava sessão expirada")
        } catch let error as APIError {
            guard case .sessionExpired = error else {
                return XCTFail("esperava sessionExpired, recebeu \(error)")
            }
        } catch {
            XCTFail("erro inesperado: \(error)")
        }
    }

    private static func response(
        _ request: URLRequest,
        status: Int,
        body: Data = Data()
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response, body)
    }

    private static func refreshBody(email: String) -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "access_token": "refreshed-access",
            "refresh_token": "refreshed-refresh",
            "expires_in": 3600,
            "user": ["email": email],
        ])
    }
}

final class HomeShellStateTests: XCTestCase {

    func testDockUsesLockedGeometry() {
        XCTAssertEqual(HomeDockLayout.navigationWidth, 236.8, accuracy: 0.001)
        XCTAssertEqual(HomeDockLayout.actionWidth, 58, accuracy: 0.001)
        XCTAssertEqual(HomeDockLayout.height, 58, accuracy: 0.001)
        XCTAssertEqual(HomeDockLayout.gap, 8, accuracy: 0.001)
    }

    func testOnlyApprovedDestinationsArePersistent() {
        XCTAssertEqual(
            HomeDestination.allCases,
            [.inicio, .eventos, .catalogo]
        )
    }

    func testIdentifyPreservesThePreviousDestination() {
        var shell = HomeShellState(destination: .catalogo)

        shell.openIdentify()

        XCTAssertEqual(shell.destination, .catalogo)
        XCTAssertEqual(shell.operation, .identify)

        shell.closeOperation()

        XCTAssertEqual(shell.destination, .catalogo)
        XCTAssertNil(shell.operation)
    }

    func testSettingsPreservesThePreviousDestination() {
        var shell = HomeShellState(destination: .eventos)

        shell.openSettings()

        XCTAssertEqual(shell.destination, .eventos)
        XCTAssertTrue(shell.showsSettings)

        shell.closeSettings()

        XCTAssertEqual(shell.destination, .eventos)
        XCTAssertFalse(shell.showsSettings)
    }
}
