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

        client = APIClient(session: mockSession, authStore: authStore)
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
