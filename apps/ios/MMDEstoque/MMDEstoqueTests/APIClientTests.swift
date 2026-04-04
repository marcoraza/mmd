import XCTest
@testable import MMD_Estoque

final class APIClientTests: XCTestCase {

    // MARK: - Not Configured

    @MainActor
    func testResolveRfidTagsThrowsWhenNotConfigured() async {
        // Ensure config is empty
        let savedUrl = AppConfig.shared.supabaseUrl
        let savedKey = AppConfig.shared.supabaseAnonKey
        AppConfig.shared.save(supabaseUrl: "", anonKey: "")

        defer {
            AppConfig.shared.save(supabaseUrl: savedUrl, anonKey: savedKey)
        }

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
        let savedUrl = AppConfig.shared.supabaseUrl
        let savedKey = AppConfig.shared.supabaseAnonKey
        AppConfig.shared.save(supabaseUrl: "", anonKey: "")

        defer {
            AppConfig.shared.save(supabaseUrl: savedUrl, anonKey: savedKey)
        }

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
        XCTAssertNotNil(APIError.httpError(statusCode: 404, body: "Not found").errorDescription)
        XCTAssertTrue(APIError.httpError(statusCode: 404, body: nil).errorDescription!.contains("404"))
    }
}
