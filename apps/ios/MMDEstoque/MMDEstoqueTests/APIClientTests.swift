import XCTest
@testable import MMD_Estoque

final class APIClientTests: XCTestCase {

    private var savedSupabaseUrl: String = ""
    private var savedSupabaseKey: String = ""
    private var savedWebApiUrl: String = ""
    private var savedWebApiAuthToken: String = ""
    private var savedUseMockRFID: Bool = true

    @MainActor
    override func setUp() {
        super.setUp()
        savedSupabaseUrl = AppConfig.shared.supabaseUrl
        savedSupabaseKey = AppConfig.shared.supabaseAnonKey
        savedWebApiUrl = AppConfig.shared.webApiUrl
        savedWebApiAuthToken = AppConfig.shared.webApiAuthToken
        savedUseMockRFID = AppConfig.shared.useMockRFID

        AppConfig.shared.save(
            supabaseUrl: "",
            anonKey: "",
            webApiUrl: "",
            webApiAuthToken: "",
            useMockRFID: savedUseMockRFID
        )
    }

    @MainActor
    override func tearDown() {
        AppConfig.shared.save(
            supabaseUrl: savedSupabaseUrl,
            anonKey: savedSupabaseKey,
            webApiUrl: savedWebApiUrl,
            webApiAuthToken: savedWebApiAuthToken,
            useMockRFID: savedUseMockRFID
        )
        super.tearDown()
    }

    // MARK: - Not Configured

    @MainActor
    func testResolveRfidTagsThrowsWhenNotConfigured() async {
        let client = APIClient()

        do {
            _ = try await client.resolveRfidTags(["TAG1", "TAG2"])
            XCTFail("Expected notConfigured error")
        } catch let error as APIError {
            if case .notConfigured = error {
                // Expected
            } else {
                XCTFail("Expected notConfigured, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    @MainActor
    func testFetchProjectsThrowsWhenNotConfigured() async {
        let client = APIClient()

        do {
            _ = try await client.fetchProjects(status: [.confirmado])
            XCTFail("Expected notConfigured error")
        } catch let error as APIError {
            if case .notConfigured = error {
                // Expected
            } else {
                XCTFail("Expected notConfigured, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    @MainActor
    func testCheckoutProjectThrowsWhenWebApiNotConfigured() async {
        let client = APIClient()

        do {
            _ = try await client.checkoutProject(projectId: UUID(), metodoScan: .rfid)
            XCTFail("Expected webApiNotConfigured error")
        } catch let error as APIError {
            if case .webApiNotConfigured = error {
                // Expected
            } else {
                XCTFail("Expected webApiNotConfigured, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    @MainActor
    func testReturnProjectThrowsWhenWebApiNotConfigured() async {
        let client = APIClient()

        do {
            _ = try await client.returnProject(
                projectId: UUID(),
                metodoScan: .rfid,
                items: []
            )
            XCTFail("Expected webApiNotConfigured error")
        } catch let error as APIError {
            if case .webApiNotConfigured = error {
                // Expected
            } else {
                XCTFail("Expected webApiNotConfigured, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    @MainActor
    func testRecordRfidScansThrowsWhenWebApiNotConfigured() async {
        let client = APIClient()

        do {
            _ = try await client.recordRfidScans(
                tags: ["E28011702000020A5C41B6E0"],
                contexto: .inventario
            )
            XCTFail("Expected webApiNotConfigured error")
        } catch let error as APIError {
            if case .webApiNotConfigured = error {
                // Expected
            } else {
                XCTFail("Expected webApiNotConfigured, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    @MainActor
    func testRecordAndResolveFallsBackToLegacyResolveWhenWebApiNotConfigured() async {
        // Without web API, recordAndResolveRfidTags must call resolveRfidTags,
        // which throws notConfigured when Supabase is empty in tests.
        let client = APIClient()

        do {
            _ = try await client.recordAndResolveRfidTags(
                tags: ["TAG1"],
                contexto: .checkOutEvento
            )
            XCTFail("Expected notConfigured from legacy resolve path")
        } catch let error as APIError {
            if case .notConfigured = error {
                // Expected fallback path
            } else {
                XCTFail("Expected notConfigured from legacy resolve, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - DTO Decode (snake_case fixtures)

    func testDecodeRfidScanResponseFromSnakeCaseJSON() throws {
        let data = """
        {
          "resolved": [
            {
              "tag_rfid": "E28011702000020A5C41B6E0",
              "serial_id": "77777777-7777-7777-7777-777777777777",
              "codigo_interno": "MMD-ILU-0001",
              "item_nome": "Moving Beam 7R"
            }
          ],
          "unresolved": ["UNKNOWN1"],
          "scan_ids": ["88888888-8888-8888-8888-888888888888"]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(RfidScanResponse.self, from: data)
        XCTAssertEqual(response.resolved.count, 1)
        XCTAssertEqual(response.resolved.first?.codigoInterno, "MMD-ILU-0001")
        XCTAssertEqual(response.resolved.first?.tagRfid, "E28011702000020A5C41B6E0")
        XCTAssertEqual(response.unresolved, ["UNKNOWN1"])
        XCTAssertEqual(response.scanIds.count, 1)
    }

    func testDecodeCheckoutProjectResponseFromSnakeCaseJSON() throws {
        let data = """
        {
          "count": 1,
          "seriais": [
            {
              "serial_id": "33333333-3333-3333-3333-333333333333",
              "codigo_interno": "MMD-AUD-0002"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CheckoutProjectResponse.self, from: data)
        XCTAssertEqual(response.count, 1)
        XCTAssertEqual(response.seriais.first?.codigoInterno, "MMD-AUD-0002")
        XCTAssertEqual(
            response.seriais.first?.serialId.uuidString,
            "33333333-3333-3333-3333-333333333333"
        )
    }

    // MARK: - Empty Input

    @MainActor
    func testResolveRfidTagsReturnsEmptyForEmptyInput() async throws {
        let client = APIClient()
        let result = try await client.resolveRfidTags([])
        XCTAssertTrue(result.resolved.isEmpty)
        XCTAssertTrue(result.unresolved.isEmpty)
    }

    @MainActor
    func testFetchSerialsByIdsReturnsEmptyForEmptyInput() async throws {
        let client = APIClient()
        let result = try await client.fetchSerialsByIds([])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - APIError Descriptions

    func testAPIErrorDescriptions() {
        XCTAssertNotNil(APIError.invalidURL.errorDescription)
        XCTAssertNotNil(APIError.notConfigured.errorDescription)
        XCTAssertNotNil(APIError.webApiNotConfigured.errorDescription)
        XCTAssertNotNil(APIError.sessionExpired.errorDescription)
        XCTAssertTrue(APIError.sessionExpired.errorDescription!.contains("login"))
        XCTAssertNotNil(APIError.httpError(statusCode: 404, body: "Not found").errorDescription)
        XCTAssertTrue(APIError.httpError(statusCode: 404, body: nil).errorDescription!.contains("404"))
    }
}
