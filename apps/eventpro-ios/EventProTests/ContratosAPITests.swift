import XCTest
@testable import EventPro

/// Fixtures copiadas de `docs/contratos-api.md`. Se um destes testes quebrar,
/// ou o contrato mudou (e precisa de versão nova do documento), ou o modelo
/// saiu do contrato.
final class ContratosAPITests: XCTestCase {

    private let decoder = APIClient.makeDecoder()
    private let encoder = JSONEncoder()

    private func json(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Seção 2: checkout

    func testCheckoutRequestOmiteOverrideReasonQuandoNil() throws {
        let body = try encoder.encode(CheckoutProjectRequest(metodo: "RFID", overrideReason: nil))
        let objeto = try json(body)

        XCTAssertEqual(objeto["metodo"] as? String, "RFID")
        XCTAssertNil(objeto["overrideReason"], "Caminho feliz manda só `metodo`")
        XCTAssertEqual(objeto.keys.count, 1)
    }

    /// D6: `overrideReason` é o único campo camelCase de toda a superfície.
    func testCheckoutRequestUsaCamelCaseNoOverrideReason() throws {
        let body = try encoder.encode(
            CheckoutProjectRequest(metodo: "RFID", overrideReason: "Cliente aceitou sair com 2 refletores a menos")
        )
        let objeto = try json(body)

        XCTAssertNotNil(objeto["overrideReason"])
        XCTAssertNil(objeto["override_reason"])
    }

    func testCheckoutResponseDecodifica() throws {
        let data = """
        {
          "count": 2,
          "seriais": [
            { "serial_id": "1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01", "codigo_interno": "MMD-ILU-0001" },
            { "serial_id": "6f3b9d2a-1c44-4a11-b1b7-9a1b2c3d4e5f", "codigo_interno": "MMD-ILU-0002" }
          ]
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(CheckoutProjectResponse.self, from: data)
        XCTAssertEqual(response.count, 2)
        XCTAssertEqual(response.seriais.first?.codigoInterno, "MMD-ILU-0001")
    }

    /// Evento 100 por cento terceirizado devolve `count: 0` e isso é sucesso.
    func testCheckoutResponseAceitaListaVazia() throws {
        let data = #"{ "count": 0, "seriais": [] }"#.data(using: .utf8)!
        let response = try decoder.decode(CheckoutProjectResponse.self, from: data)
        XCTAssertEqual(response.count, 0)
    }

    /// Campo extra na resposta precisa ser ignorado (mudança aditiva é segura).
    func testCheckoutResponseIgnoraCampoDesconhecido() throws {
        let data = """
        { "count": 1, "seriais": [{ "serial_id": "1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01",
          "codigo_interno": "MMD-ILU-0001", "campo_novo": true }], "meta": { "x": 1 } }
        """.data(using: .utf8)!
        XCTAssertNoThrow(try decoder.decode(CheckoutProjectResponse.self, from: data))
    }

    // MARK: - Seção 3: retorno

    func testReturnItemSerializaSnakeCase() throws {
        let item = ReturnProjectItemRequest(
            serialId: UUID(uuidString: "1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01")!,
            desgaste: 4,
            resultado: .ok,
            observacao: nil
        )
        let objeto = try json(try encoder.encode(item))

        XCTAssertNotNil(objeto["serial_id"])
        XCTAssertEqual(objeto["desgaste"] as? Int, 4)
        XCTAssertEqual(objeto["resultado"] as? String, "OK")
        XCTAssertNil(objeto["observacao"], "observacao nil sai do JSON")
    }

    func testReturnOutcomeRawValues() {
        XCTAssertEqual(ReturnProjectOutcome.ok.rawValue, "OK")
        XCTAssertEqual(ReturnProjectOutcome.problema.rawValue, "PROBLEMA")
        XCTAssertEqual(ReturnProjectOutcome.naoVoltou.rawValue, "NAO_VOLTOU")
        XCTAssertEqual(ReturnProjectOutcome.allCases.count, 3)
    }

    func testReturnResponseDecodificaOsTresDestinos() throws {
        let data = """
        {
          "count": 3,
          "seriais": [
            { "serial_id": "1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01", "codigo_interno": "MMD-ILU-0001", "novo_status": "DISPONIVEL" },
            { "serial_id": "6f3b9d2a-1c44-4a11-b1b7-9a1b2c3d4e5f", "codigo_interno": "MMD-CAB-0044", "novo_status": "MANUTENCAO" },
            { "serial_id": "9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d", "codigo_interno": "MMD-AUD-0012", "novo_status": "RETORNANDO" }
          ]
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(ReturnProjectResponse.self, from: data)
        XCTAssertEqual(response.seriais.map(\.novoStatus), ["DISPONIVEL", "MANUTENCAO", "RETORNANDO"])
    }

    // MARK: - Seção 4: resumo

    func testEventoResumoDecodifica() throws {
        let data = """
        {
          "id": "3c0d2f11-6b8a-4d55-9a10-0b7e2c4f8d31",
          "nome": "Festival Verão 2026",
          "cliente": "Prefeitura de Ilhabela",
          "data_inicio": "2026-08-14",
          "data_fim": "2026-08-16",
          "local": "Praça Central",
          "status": "CONFIRMADO",
          "notas": null,
          "ficha_evento": null,
          "packing": { "linhas": 12, "itens_total": 87, "itens_alocados": 81, "readiness_pct": 93 }
        }
        """.data(using: .utf8)!

        let resumo = try decoder.decode(EventoResumo.self, from: data)
        XCTAssertEqual(resumo.nome, "Festival Verão 2026")
        XCTAssertEqual(resumo.status, .confirmado)
        XCTAssertEqual(resumo.packing.readinessPct, 93)
        XCTAssertEqual(resumo.packing.readinessFraction, 0.93, accuracy: 0.0001)
        XCTAssertEqual(resumo.asProject.dataInicioFormatado?.isEmpty, false)
    }

    /// `MONTAGEM` existe no contrato e o app legado não conhecia.
    func testStatusProjetoCobreMontagem() throws {
        let data = """
        { "id": "3c0d2f11-6b8a-4d55-9a10-0b7e2c4f8d31", "nome": "X", "cliente": null,
          "data_inicio": null, "data_fim": null, "local": null, "status": "MONTAGEM",
          "notas": null, "packing": { "linhas": 0, "itens_total": 0, "itens_alocados": 0, "readiness_pct": 0 } }
        """.data(using: .utf8)!

        let resumo = try decoder.decode(EventoResumo.self, from: data)
        XCTAssertEqual(resumo.status, .montagem)
        XCTAssertTrue(resumo.status.permiteCheckout)
        XCTAssertEqual(StatusProjeto.allCases.count, 6)
    }

    func testStatusProjetoRegrasDeFase() {
        XCTAssertTrue(StatusProjeto.confirmado.permiteCheckout)
        XCTAssertTrue(StatusProjeto.montagem.permiteCheckout)
        XCTAssertFalse(StatusProjeto.planejamento.permiteCheckout)
        XCTAssertFalse(StatusProjeto.emCampo.permiteCheckout)
        XCTAssertTrue(StatusProjeto.emCampo.permiteRetorno)
        XCTAssertFalse(StatusProjeto.finalizado.permiteRetorno)
    }

    // MARK: - Seção 5: scan RFID

    func testRfidScanRequestOmiteCamposAditivosQuandoNil() throws {
        let request = RfidScanRequest(
            tags: ["E28011700000020D1A2B3C4D"],
            contexto: .checkOutEvento,
            projetoId: UUID(uuidString: "3c0d2f11-6b8a-4d55-9a10-0b7e2c4f8d31")!
        )
        let objeto = try json(try encoder.encode(request))

        XCTAssertEqual(objeto["contexto"] as? String, "CHECK_OUT_EVENTO")
        XCTAssertNotNil(objeto["projeto_id"])
        XCTAssertNil(objeto["localizacao"])
        XCTAssertNil(objeto["rssi_por_tag"], "Sem RSSI, o corpo fica idêntico ao do legado")
        XCTAssertNil(objeto["reader"])
    }

    /// D7: `rssi_por_tag` é aditivo. Só aparece quando existe RSSI de verdade.
    func testRfidScanRequestIncluiRssiQuandoPresente() throws {
        let request = RfidScanRequest(
            tags: ["E28011700000020D1A2B3C4D"],
            contexto: .conferencia,
            rssiPorTag: ["E28011700000020D1A2B3C4D": -42]
        )
        let objeto = try json(try encoder.encode(request))
        let rssi = try XCTUnwrap(objeto["rssi_por_tag"] as? [String: Int])
        XCTAssertEqual(rssi["E28011700000020D1A2B3C4D"], -42)
    }

    func testRfidScanRequestTrataMapaVazioComoAusente() throws {
        let request = RfidScanRequest(tags: ["E28011700000020D1A2B3C4D"], contexto: .conferencia, rssiPorTag: [:])
        XCTAssertNil(try json(try encoder.encode(request))["rssi_por_tag"])
    }

    func testReaderRequestSerializaSerialFabrica() throws {
        let reader = RfidScanReaderRequest(
            nome: "RFD40 Marcelo",
            modelo: "Zebra RFD40",
            serialFabrica: "RFD4090-ABC123",
            bateria: 87
        )
        let objeto = try json(try encoder.encode(reader))
        XCTAssertEqual(objeto["serial_fabrica"] as? String, "RFD4090-ABC123")
        XCTAssertEqual(objeto["bateria"] as? Int, 87)
    }

    func testRfidScanResponseDecodifica() throws {
        let data = """
        {
          "resolved": [
            { "tag_rfid": "E28011700000020D1A2B3C4D", "serial_id": "1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01",
              "codigo_interno": "MMD-ILU-0001", "item_nome": "Moving Head Beam 230" }
          ],
          "unresolved": ["E28011700000020D1A2B3C4E"],
          "scan_ids": ["0a1b2c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d", "1b2c3d4e-5f6a-4b7c-9d8e-1f2a3b4c5d6e"]
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(RfidScanResponse.self, from: data)
        XCTAssertEqual(response.resolved.first?.codigoInterno, "MMD-ILU-0001")
        XCTAssertEqual(response.unresolved, ["E28011700000020D1A2B3C4E"])
        // Uma linha de scan por tag do lote, resolvida ou não.
        XCTAssertEqual(response.resolved.count + response.unresolved.count, response.scanIds.count)
    }

    func testRfidScanContextCobreOsOitoValores() {
        XCTAssertEqual(RfidScanContext.allCases.count, 8)
        XCTAssertEqual(RfidScanContext.checkOutEvento.rawValue, "CHECK_OUT_EVENTO")
        XCTAssertEqual(RfidScanContext.checkInEvento.rawValue, "CHECK_IN_EVENTO")
    }

    // MARK: - Seção 7: conferência RFID

    func testConferenciaRequestSerializa() throws {
        let request = ConferenciaRfidRequest(
            tags: ["E28011700000020D1A2B3C4D"],
            contexto: .carregamento,
            reader: RfidScanReaderRequest(nome: nil, modelo: "Zebra RFD40", serialFabrica: "RFD4090-ABC123", bateria: 71)
        )
        let objeto = try json(try encoder.encode(request))

        XCTAssertEqual(objeto["contexto"] as? String, "CARREGAMENTO")
        XCTAssertNotNil(objeto["reader"])
        XCTAssertNil(objeto["localizacao"])
    }

    func testConferenciaContextoRestritoATresValores() {
        XCTAssertEqual(ConferenciaContexto.allCases.count, 3)
        XCTAssertEqual(
            Set(ConferenciaContexto.allCases.map(\.rawValue)),
            ["CARREGAMENTO", "RETORNO", "CONFERENCIA"]
        )
    }

    func testConferenciaResponseDecodificaEInvariantes() throws {
        let data = """
        {
          "evento": { "id": "3c0d2f11-6b8a-4d55-9a10-0b7e2c4f8d31", "nome": "Festival Verão 2026", "status": "MONTAGEM" },
          "contexto": "CARREGAMENTO",
          "confirmados": [
            { "serial_id": "1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01", "codigo_interno": "MMD-ILU-0001",
              "item_nome": "Moving Head Beam 230", "tag_rfid": "E28011700000020D1A2B3C4D" }
          ],
          "faltantes": [
            { "serial_id": "6f3b9d2a-1c44-4a11-b1b7-9a1b2c3d4e5f", "codigo_interno": "MMD-AUD-0012",
              "item_nome": "Caixa Ativa 15\\"", "tag_rfid": null }
          ],
          "extras": [
            { "serial_id": "9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d", "codigo_interno": "MMD-CAB-0044",
              "item_nome": "Cabo XLR 10m", "tag_rfid": "E28011700000020D1A2B3C4E" }
          ],
          "desconhecidas": ["E28011700000020DFFFFFFFF"],
          "resumo": { "esperados": 2, "confirmados": 1, "faltantes": 1, "extras": 1, "desconhecidas": 1, "cobertura_pct": 50 },
          "scan_ids": ["0a1b2c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d", "1b2c3d4e-5f6a-4b7c-9d8e-1f2a3b4c5d6e",
                       "2c3d4e5f-6a7b-4c8d-9e0f-2a3b4c5d6e7f"]
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(ConferenciaRfidResponse.self, from: data)

        XCTAssertEqual(response.evento?.status, .montagem)
        XCTAssertEqual(response.contexto, .carregamento)
        XCTAssertEqual(response.resumoEfetivo.coberturaPct, 50)

        // Invariantes do contrato (§ 7.4).
        let tagsLidas = response.confirmados.count + response.extras.count + response.desconhecidas.count
        XCTAssertEqual(tagsLidas, response.scanIds?.count)
        XCTAssertEqual(response.confirmados.count + response.faltantes.count, response.resumoEfetivo.esperados)

        // Faltante sem tag é justamente o caso a destacar na UI.
        XCTAssertTrue(response.faltantes[0].semTagVinculada)
        XCTAssertFalse(response.confirmados[0].semTagVinculada)
    }

    /// Os campos aditivos podem faltar sem quebrar o decode.
    func testConferenciaResponseSemCamposAditivos() throws {
        let data = """
        { "confirmados": [], "faltantes": [], "extras": [], "desconhecidas": [] }
        """.data(using: .utf8)!

        let response = try decoder.decode(ConferenciaRfidResponse.self, from: data)
        XCTAssertNil(response.resumo)
        XCTAssertEqual(response.resumoEfetivo.esperados, 0)
        XCTAssertEqual(response.resumoEfetivo.coberturaPct, 0, "esperados = 0 devolve 0, não divisão por zero")
    }

    func testCoberturaArredonda() {
        XCTAssertEqual(ConferenciaRfidResponse.cobertura(confirmados: 1, esperados: 3), 33)
        XCTAssertEqual(ConferenciaRfidResponse.cobertura(confirmados: 2, esperados: 3), 67)
        XCTAssertEqual(ConferenciaRfidResponse.cobertura(confirmados: 0, esperados: 0), 0)
    }

    // MARK: - Seção 8: busca de seriais

    func testSerialBuscaQueryAplicaDefaultsETeto() {
        let query = SerialBuscaQuery(q: "  beam 230 ", semTag: true, limit: 500, offset: -10)

        XCTAssertEqual(query.q, "beam 230")
        XCTAssertEqual(query.limit, SerialBuscaQuery.maxLimit, "limit acima de 100 é reduzido, não recusado")
        XCTAssertEqual(query.offset, 0)
        XCTAssertTrue(query.isTermValid)
    }

    func testSerialBuscaQueryValidaTermo() {
        XCTAssertFalse(SerialBuscaQuery(q: "a").isTermValid, "mínimo 2 caracteres")
        XCTAssertFalse(SerialBuscaQuery(q: String(repeating: "a", count: 65)).isTermValid)
        XCTAssertFalse(SerialBuscaQuery(q: "beam,230").isTermValid, "vírgula quebra filtro PostgREST")
        XCTAssertFalse(SerialBuscaQuery(q: "in.(\"a\")").isTermValid)
        XCTAssertFalse(SerialBuscaQuery(q: "beam*").isTermValid)
        XCTAssertTrue(SerialBuscaQuery(q: "MMD-ILU-0001").isTermValid)
        XCTAssertTrue(SerialBuscaQuery(q: nil).isTermValid, "sem termo é página inicial, não erro")
    }

    func testSerialBuscaQueryItems() {
        let itemId = UUID(uuidString: "8F1C0A22-9D3E-4B77-A6C1-5E2D7F0B1234")!
        let items = SerialBuscaQuery(q: "beam", itemId: itemId, semTag: true, limit: 50, offset: 50).queryItems
        let mapa = Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })

        XCTAssertEqual(mapa["q"], "beam")
        XCTAssertEqual(mapa["item_id"], "8f1c0a22-9d3e-4b77-a6c1-5e2d7f0b1234")
        XCTAssertEqual(mapa["sem_tag"], "true")
        XCTAssertEqual(mapa["limit"], "50")
        XCTAssertEqual(mapa["offset"], "50")
    }

    func testSerialBuscaNextPage() {
        let primeira = SerialBuscaQuery(q: "beam", limit: 25, offset: 0)
        XCTAssertEqual(primeira.nextPage(loaded: 25).offset, 25)
        XCTAssertEqual(primeira.nextPage(loaded: 25).q, "beam")
    }

    func testSerialBuscaResponseDecodifica() throws {
        let data = """
        {
          "items": [
            { "serial_id": "1f2b7c1e-4a63-4f0e-9d70-9c2a1f9f1a01", "codigo_interno": "MMD-ILU-0001",
              "item_nome": "Moving Head Beam 230", "tag_rfid": "E28011700000020D1A2B3C4D" },
            { "serial_id": "2a3b4c5d-6e7f-4a8b-9c0d-1e2f3a4b5c6d", "codigo_interno": "MMD-ILU-0002",
              "item_nome": "Moving Head Beam 230", "tag_rfid": null }
          ],
          "total": 42, "limit": 25, "offset": 0, "has_more": true
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(SerialBuscaResponse.self, from: data)
        XCTAssertEqual(response.total, 42)
        XCTAssertTrue(response.hasMore)
        XCTAssertTrue(response.items[0].temTag)
        XCTAssertFalse(response.items[1].temTag, "tag_rfid null é o caso alvo do fluxo de vínculo")
    }

    // MARK: - Métodos de scan

    func testMetodoScanRawValues() {
        XCTAssertEqual(MetodoScan.rfid.rawValue, "RFID")
        XCTAssertEqual(MetodoScan.qrcode.rawValue, "QRCODE")
        XCTAssertEqual(MetodoScan.manual.rawValue, "MANUAL")
        XCTAssertEqual(MetodoScan.allCases.count, 3)
    }
}
