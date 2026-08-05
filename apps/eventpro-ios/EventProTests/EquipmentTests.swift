import XCTest
@testable import EventPro

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

    /// Os prefixos continuam os do MMD: as etiquetas físicas já estão coladas.
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

    // MARK: - Display

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

    func testEquipmentDisplayNameFallsBackToNome() {
        let eq = Equipment(id: UUID(), nome: "Cabo XLR 10m", categoria: .cabo)
        XCTAssertEqual(eq.displayName, "Cabo XLR 10m")
    }

    // MARK: - Decode

    func testEquipmentDecodesFromSupabaseJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "nome": "Moving Head Beam 230",
            "categoria": "ILUMINACAO",
            "subcategoria": "Beam",
            "marca": "Elation",
            "modelo": "Platinum Beam",
            "tipo_rastreamento": "INDIVIDUAL",
            "quantidade_total": 12,
            "valor_mercado_unitario": 8500.0,
            "foto_url": null,
            "notas": null
        }
        """.data(using: .utf8)!

        let eq = try APIClient.makeDecoder().decode(Equipment.self, from: json)

        XCTAssertEqual(eq.categoria, .iluminacao)
        XCTAssertEqual(eq.tipoRastreamento, .individual)
        XCTAssertEqual(eq.quantidadeTotal, 12)
        XCTAssertEqual(eq.valorMercadoUnitario, 8500.0)
    }
}
