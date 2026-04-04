import XCTest
@testable import MMD_Estoque

final class EquipmentTests: XCTestCase {

    // MARK: - Categoria

    func testCategoriaDisplayNames() {
        XCTAssertEqual(Categoria.iluminacao.displayName, "Iluminacao")
        XCTAssertEqual(Categoria.audio.displayName, "Audio")
        XCTAssertEqual(Categoria.cabo.displayName, "Cabo")
        XCTAssertEqual(Categoria.energia.displayName, "Energia")
        XCTAssertEqual(Categoria.estrutura.displayName, "Estrutura")
        XCTAssertEqual(Categoria.efeito.displayName, "Efeito")
        XCTAssertEqual(Categoria.video.displayName, "Video")
        XCTAssertEqual(Categoria.acessorio.displayName, "Acessorio")
    }

    func testCategoriaPrefixes() {
        XCTAssertEqual(Categoria.iluminacao.prefix, "ILU")
        XCTAssertEqual(Categoria.audio.prefix, "AUD")
        XCTAssertEqual(Categoria.cabo.prefix, "CAB")
        XCTAssertEqual(Categoria.energia.prefix, "ENE")
        XCTAssertEqual(Categoria.estrutura.prefix, "EST")
        XCTAssertEqual(Categoria.efeito.prefix, "EFE")
        XCTAssertEqual(Categoria.video.prefix, "VID")
        XCTAssertEqual(Categoria.acessorio.prefix, "ACE")
    }

    func testCategoriaCaseIterable() {
        XCTAssertEqual(Categoria.allCases.count, 8)
    }

    func testCategoriaRawValues() {
        XCTAssertEqual(Categoria.iluminacao.rawValue, "ILUMINACAO")
        XCTAssertEqual(Categoria.audio.rawValue, "AUDIO")
        XCTAssertEqual(Categoria.cabo.rawValue, "CABO")
    }

    // MARK: - TipoRastreamento

    func testTipoRastreamentoDisplayNames() {
        XCTAssertEqual(TipoRastreamento.individual.displayName, "Individual")
        XCTAssertEqual(TipoRastreamento.lote.displayName, "Lote")
        XCTAssertEqual(TipoRastreamento.bulk.displayName, "Bulk")
    }

    // MARK: - Equipment Display

    func testEquipmentDisplayNameWithBrandAndModel() {
        let eq = Equipment(
            id: UUID(),
            nome: "Moving Head Spot 350W",
            categoria: .iluminacao,
            marca: "Elation",
            modelo: "Platinum Spot 5R"
        )
        XCTAssertEqual(eq.displayName, "Elation Platinum Spot 5R")
    }

    func testEquipmentDisplayNameWithoutBrand() {
        let eq = Equipment(
            id: UUID(),
            nome: "Cabo DMX 10m",
            categoria: .cabo
        )
        XCTAssertEqual(eq.displayName, "Cabo DMX 10m")
    }

    func testEquipmentDisplayNameBrandOnly() {
        let eq = Equipment(
            id: UUID(),
            nome: "Console",
            categoria: .iluminacao,
            marca: "GrandMA"
        )
        XCTAssertEqual(eq.displayName, "GrandMA")
    }

    // MARK: - Equipment JSON Decoding

    func testEquipmentDecodesFromSupabaseJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "nome": "Moving Head Wash",
            "categoria": "ILUMINACAO",
            "subcategoria": "Moving Head",
            "marca": "Elation",
            "modelo": "Platinum Wash",
            "tipo_rastreamento": "INDIVIDUAL",
            "quantidade_total": 12,
            "valor_mercado_unitario": 5500.00,
            "foto_url": null,
            "notas": null,
            "created_at": "2026-03-20T14:30:00.000000+00:00",
            "updated_at": "2026-03-20T14:30:00.000000+00:00"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = formatter.date(from: string) { return date }
            if let date = fallback.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date")
        }

        let equipment = try decoder.decode(Equipment.self, from: json)

        XCTAssertEqual(equipment.nome, "Moving Head Wash")
        XCTAssertEqual(equipment.categoria, .iluminacao)
        XCTAssertEqual(equipment.subcategoria, "Moving Head")
        XCTAssertEqual(equipment.marca, "Elation")
        XCTAssertEqual(equipment.modelo, "Platinum Wash")
        XCTAssertEqual(equipment.tipoRastreamento, .individual)
        XCTAssertEqual(equipment.quantidadeTotal, 12)
        XCTAssertEqual(equipment.valorMercadoUnitario, 5500.00)
        XCTAssertNotNil(equipment.createdAt)
    }

    func testEquipmentValorMercadoFormatado() {
        let eq = Equipment(
            id: UUID(),
            nome: "Test",
            categoria: .audio,
            valorMercadoUnitario: 1200.00
        )
        let formatted = eq.valorMercadoFormatado
        XCTAssertNotNil(formatted)
        // Brazilian format: R$ 1.200,00
        XCTAssertTrue(formatted!.contains("1.200"), "Expected formatted value to contain '1.200', got: \(formatted!)")
    }
}
