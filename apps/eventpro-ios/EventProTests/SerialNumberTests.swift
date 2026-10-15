import XCTest
@testable import EventPro

final class SerialNumberTests: XCTestCase {

    // MARK: - StatusSerial

    func testStatusSerialAllRawValues() {
        XCTAssertEqual(StatusSerial.disponivel.rawValue, "DISPONIVEL")
        XCTAssertEqual(StatusSerial.packed.rawValue, "PACKED")
        XCTAssertEqual(StatusSerial.emCampo.rawValue, "EM_CAMPO")
        XCTAssertEqual(StatusSerial.retornando.rawValue, "RETORNANDO")
        XCTAssertEqual(StatusSerial.manutencao.rawValue, "MANUTENCAO")
        XCTAssertEqual(StatusSerial.emprestado.rawValue, "EMPRESTADO")
        XCTAssertEqual(StatusSerial.vendido.rawValue, "VENDIDO")
        XCTAssertEqual(StatusSerial.baixa.rawValue, "BAIXA")
    }

    func testStatusSerialCaseCount() {
        XCTAssertEqual(StatusSerial.allCases.count, 8)
    }

    func testStatusSerialIsActive() {
        XCTAssertFalse(StatusSerial.disponivel.isActive)
        XCTAssertFalse(StatusSerial.packed.isActive)
        XCTAssertTrue(StatusSerial.emCampo.isActive)
        XCTAssertTrue(StatusSerial.retornando.isActive)
        XCTAssertFalse(StatusSerial.manutencao.isActive)
        XCTAssertFalse(StatusSerial.emprestado.isActive)
        XCTAssertFalse(StatusSerial.vendido.isActive)
        XCTAssertFalse(StatusSerial.baixa.isActive)
    }

    func testStatusSerialIsAvailable() {
        XCTAssertTrue(StatusSerial.disponivel.isAvailable)
        for status in StatusSerial.allCases where status != .disponivel {
            XCTAssertFalse(status.isAvailable, "\(status.rawValue) nao deveria estar disponivel")
        }
    }

    // MARK: - Estado

    func testEstadoFatorDepreciacao() {
        XCTAssertEqual(Estado.novo.fatorDepreciacao, 1.00)
        XCTAssertEqual(Estado.semiNovo.fatorDepreciacao, 0.85)
        XCTAssertEqual(Estado.usado.fatorDepreciacao, 0.65)
        XCTAssertEqual(Estado.recondicionado.fatorDepreciacao, 0.50)
    }

    func testEstadoDisplayNames() {
        XCTAssertEqual(Estado.novo.displayName, "Novo")
        XCTAssertEqual(Estado.semiNovo.displayName, "Semi-Novo")
        XCTAssertEqual(Estado.usado.displayName, "Usado")
        XCTAssertEqual(Estado.recondicionado.displayName, "Recondicionado")
    }

    // MARK: - calcularValorAtual

    func testCalcularValorAtualNovoDesgaste5() {
        XCTAssertEqual(makeSerial(estado: .novo, desgaste: 5).calcularValorAtual(valorOriginal: 10000), 10000.0)
    }

    func testCalcularValorAtualUsadoDesgaste3() {
        // 10000 * (3/5) * 0.65 = 3900
        XCTAssertEqual(makeSerial(estado: .usado, desgaste: 3).calcularValorAtual(valorOriginal: 10000), 3900.0)
    }

    func testCalcularValorAtualSemiNovoDesgaste4() {
        // 10000 * (4/5) * 0.85 = 6800
        XCTAssertEqual(makeSerial(estado: .semiNovo, desgaste: 4).calcularValorAtual(valorOriginal: 10000), 6800.0)
    }

    func testCalcularValorAtualRecondicionadoDesgaste1() {
        // 10000 * (1/5) * 0.50 = 1000
        XCTAssertEqual(
            makeSerial(estado: .recondicionado, desgaste: 1).calcularValorAtual(valorOriginal: 10000),
            1000.0
        )
    }

    func testCalcularValorAtualZeroOriginal() {
        XCTAssertEqual(makeSerial(estado: .novo, desgaste: 5).calcularValorAtual(valorOriginal: 0), 0.0)
    }

    // MARK: - Desgaste

    func testDesgasteLabels() {
        XCTAssertEqual(makeSerial(desgaste: 5).desgasteLabel, "Excelente")
        XCTAssertEqual(makeSerial(desgaste: 4).desgasteLabel, "Bom")
        XCTAssertEqual(makeSerial(desgaste: 3).desgasteLabel, "Regular")
        XCTAssertEqual(makeSerial(desgaste: 2).desgasteLabel, "Desgastado")
        XCTAssertEqual(makeSerial(desgaste: 1).desgasteLabel, "Critico")
        XCTAssertEqual(makeSerial(desgaste: 0).desgasteLabel, "Desconhecido")
    }

    // MARK: - Decode

    func testSerialNumberDecodesFromSupabaseJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440001",
            "item_id": "550e8400-e29b-41d4-a716-446655440000",
            "codigo_interno": "MMD-ILU-0001",
            "serial_fabrica": "SN123456",
            "tag_rfid": "E28011702000020A5C41B6E0",
            "qr_code": "MMD-ILU-0001",
            "status": "DISPONIVEL",
            "estado": "USADO",
            "desgaste": 3,
            "depreciacao_pct": 39.0,
            "valor_atual": 3900.0,
            "localizacao": "Deposito A",
            "notas": null,
            "created_at": "2026-03-20T14:30:00.000000+00:00",
            "updated_at": "2026-03-20T14:30:00.000000+00:00"
        }
        """.data(using: .utf8)!

        let sn = try APIClient.makeDecoder().decode(SerialNumber.self, from: json)

        XCTAssertEqual(sn.codigoInterno, "MMD-ILU-0001")
        XCTAssertEqual(sn.tagRfid, "E28011702000020A5C41B6E0")
        XCTAssertEqual(sn.status, .disponivel)
        XCTAssertEqual(sn.estado, .usado)
        XCTAssertEqual(sn.desgaste, 3)
        XCTAssertEqual(sn.valorAtual, 3900.0)
        XCTAssertEqual(sn.localizacao, "Deposito A")
        XCTAssertNotNil(sn.createdAt)
    }

    /// Nem toda coluna volta com fração de segundo. O decoder tem dois formatos.
    func testSerialNumberDecodesTimestampSemFracao() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440001",
            "item_id": "550e8400-e29b-41d4-a716-446655440000",
            "codigo_interno": "MMD-ILU-0001",
            "status": "DISPONIVEL",
            "estado": "USADO",
            "desgaste": 3,
            "created_at": "2026-03-20T14:30:00Z"
        }
        """.data(using: .utf8)!

        let sn = try APIClient.makeDecoder().decode(SerialNumber.self, from: json)
        XCTAssertNotNil(sn.createdAt)
    }

    func testSerialNumberDecodesWithNestedItem() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440001",
            "item_id": "550e8400-e29b-41d4-a716-446655440000",
            "codigo_interno": "MMD-ILU-0001",
            "status": "DISPONIVEL",
            "estado": "USADO",
            "desgaste": 3,
            "item": {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "nome": "Moving Head Wash",
                "categoria": "ILUMINACAO",
                "marca": "Elation",
                "modelo": "Platinum Wash"
            }
        }
        """.data(using: .utf8)!

        let sn = try APIClient.makeDecoder().decode(SerialNumber.self, from: json)

        XCTAssertNotNil(sn.item)
        XCTAssertEqual(sn.item?.displayName, "Elation Platinum Wash")
        XCTAssertEqual(sn.item?.categoria, .iluminacao)
    }

    // MARK: - Helpers

    private func makeSerial(estado: Estado = .usado, desgaste: Int = 3) -> SerialNumber {
        SerialNumber(
            id: UUID(),
            itemId: UUID(),
            codigoInterno: "MMD-TST-0001",
            status: .disponivel,
            estado: estado,
            desgaste: desgaste
        )
    }
}
