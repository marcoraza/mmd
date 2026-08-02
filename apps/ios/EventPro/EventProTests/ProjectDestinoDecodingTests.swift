import XCTest
@testable import EventPro

final class ProjectDestinoDecodingTests: XCTestCase {

    private var decoder: JSONDecoder!

    override func setUp() {
        super.setUp()
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: string) {
                return date
            }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Data nao reconhecida: \(string)"
            )
        }
    }

    func testDecodesLegacyEventoWithoutDestino() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "nome": "Casamento Rosa",
          "local": "Rosewood São Paulo",
          "status": "CONFIRMADO"
        }
        """.data(using: .utf8)!

        let project = try decoder.decode(Project.self, from: json)

        XCTAssertEqual(project.nome, "Casamento Rosa")
        XCTAssertEqual(project.local, "Rosewood São Paulo")
        XCTAssertNil(project.destinoLatitude)
        XCTAssertNil(project.destinoLongitude)
        XCTAssertNil(project.destinoConfirmadoEm)
        XCTAssertFalse(project.hasDestino)
    }

    func testDecodesExplicitNullDestino() throws {
        let json = """
        {
          "id": "22222222-2222-2222-2222-222222222222",
          "nome": "Festival",
          "status": "PLANEJAMENTO",
          "destino_latitude": null,
          "destino_longitude": null,
          "destino_confirmado_em": null
        }
        """.data(using: .utf8)!

        let project = try decoder.decode(Project.self, from: json)

        XCTAssertNil(project.destinoLatitude)
        XCTAssertNil(project.destinoLongitude)
        XCTAssertNil(project.destinoConfirmadoEm)
        XCTAssertFalse(project.hasDestino)
    }

    func testDecodesConfirmedDestino() throws {
        let json = """
        {
          "id": "33333333-3333-3333-3333-333333333333",
          "nome": "Corporativo",
          "status": "CONFIRMADO",
          "destino_latitude": -23.561414,
          "destino_longitude": -46.655881,
          "destino_confirmado_em": "2026-08-02T14:30:00.000000+00:00"
        }
        """.data(using: .utf8)!

        let project = try decoder.decode(Project.self, from: json)

        XCTAssertEqual(project.destinoLatitude!, -23.561414, accuracy: 0.000001)
        XCTAssertEqual(project.destinoLongitude!, -46.655881, accuracy: 0.000001)
        XCTAssertNotNil(project.destinoConfirmadoEm)
        XCTAssertTrue(project.hasDestino)
    }

    func testCodingKeysUseSnakeCaseColumnNames() {
        XCTAssertEqual(Project.CodingKeys.destinoLatitude.stringValue, "destino_latitude")
        XCTAssertEqual(Project.CodingKeys.destinoLongitude.stringValue, "destino_longitude")
        XCTAssertEqual(Project.CodingKeys.destinoConfirmadoEm.stringValue, "destino_confirmado_em")
    }
}
