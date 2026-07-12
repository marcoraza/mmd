import XCTest
@testable import MMD_Estoque

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func bodyData(from request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return Data()
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)

        while stream.hasBytesAvailable {
            let bufferSize = buffer.count
            let readCount = buffer.withUnsafeMutableBytes { rawBuffer in
                stream.read(
                    rawBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    maxLength: bufferSize
                )
            }

            if readCount < 0 {
                throw stream.streamError ?? URLError(.cannotDecodeRawData)
            }
            if readCount == 0 {
                break
            }
            data.append(buffer, count: readCount)
        }

        return data
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
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

final class APIClientTests: XCTestCase {

    @MainActor
    private func makeMockedClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return APIClient(session: URLSession(configuration: configuration))
    }

    // MARK: - Not Configured

    @MainActor
    func testResolveRfidTagsThrowsWhenNotConfigured() async {
        // Ensure config is empty
        let savedUrl = AppConfig.shared.supabaseUrl
        let savedKey = AppConfig.shared.supabaseAnonKey
        let savedUseMockRFID = AppConfig.shared.useMockRFID
        AppConfig.shared.save(supabaseUrl: "", anonKey: "", useMockRFID: savedUseMockRFID)

        defer {
            AppConfig.shared.save(supabaseUrl: savedUrl, anonKey: savedKey, useMockRFID: savedUseMockRFID)
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
        let savedUseMockRFID = AppConfig.shared.useMockRFID
        AppConfig.shared.save(supabaseUrl: "", anonKey: "", useMockRFID: savedUseMockRFID)

        defer {
            AppConfig.shared.save(supabaseUrl: savedUrl, anonKey: savedKey, useMockRFID: savedUseMockRFID)
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

    @MainActor
    func testFetchEventSummaryUsesSharedWebApi() async throws {
        let savedUrl = AppConfig.shared.supabaseUrl
        let savedKey = AppConfig.shared.supabaseAnonKey
        let savedWebApiUrl = AppConfig.shared.webApiUrl
        let savedUseMockRFID = AppConfig.shared.useMockRFID
        AppConfig.shared.save(
            supabaseUrl: "https://supabase.test",
            anonKey: "anon",
            webApiUrl: "https://mmd.test",
            useMockRFID: savedUseMockRFID
        )

        defer {
            AppConfig.shared.save(
                supabaseUrl: savedUrl,
                anonKey: savedKey,
                webApiUrl: savedWebApiUrl,
                useMockRFID: savedUseMockRFID
            )
            MockURLProtocol.requestHandler = nil
        }

        let projectId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/eventos/\(projectId.uuidString)/resumo")

            let data = """
            {
              "id": "\(projectId.uuidString)",
              "nome": "Casamento Santos & Oliveira",
              "cliente": "Familia Santos",
              "data_inicio": "2026-06-12",
              "data_fim": "2026-06-13",
              "local": "Jardim Botanico, SP",
              "status": "CONFIRMADO",
              "notas": null,
              "ficha_evento": {
                "endereco": { "local": "Casa Botanica", "endereco": null, "cidadeUf": "SP", "referenciaAcesso": null },
                "montagem": { "dia": "2026-06-12", "inicio": "08:00", "fim": null, "equipe": null, "responsavel": "Marcelo", "telefone": null },
                "desmontagem": { "dia": "2026-06-13", "inicio": "02:00", "fim": null, "equipe": null, "responsavel": null, "telefone": null },
                "responsaveis": { "principal": "Marcelo", "principalTelefone": null, "checklist": null, "checklistTelefone": null },
                "observacoes": null
              },
              "packing": { "linhas": 4, "itens_total": 52, "itens_alocados": 8, "readiness_pct": 15 }
            }
            """.data(using: .utf8)!

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }

        let summary = try await makeMockedClient().fetchEventSummary(projectId: projectId)
        XCTAssertEqual(summary.nome, "Casamento Santos & Oliveira")
        XCTAssertEqual(summary.displaySetup, "2026-06-12 08:00")
        XCTAssertEqual(summary.displayTeardown, "2026-06-13 02:00")
        XCTAssertEqual(summary.displayContact, "Marcelo")
        XCTAssertEqual(summary.packing.itensTotal, 52)
    }

    @MainActor
    func testCheckoutProjectUsesSharedWebApiBoundary() async throws {
        let savedUrl = AppConfig.shared.supabaseUrl
        let savedKey = AppConfig.shared.supabaseAnonKey
        let savedWebApiUrl = AppConfig.shared.webApiUrl
        let savedWebApiAuthToken = AppConfig.shared.webApiAuthToken
        let savedUseMockRFID = AppConfig.shared.useMockRFID
        AppConfig.shared.save(
            supabaseUrl: "https://supabase.test",
            anonKey: "anon",
            webApiUrl: "https://mmd.test",
            webApiAuthToken: "access-token",
            useMockRFID: savedUseMockRFID
        )

        defer {
            AppConfig.shared.save(
                supabaseUrl: savedUrl,
                anonKey: savedKey,
                webApiUrl: savedWebApiUrl,
                webApiAuthToken: savedWebApiAuthToken,
                useMockRFID: savedUseMockRFID
            )
            MockURLProtocol.requestHandler = nil
        }

        let projectId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/eventos/\(projectId.uuidString)/checkout")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")

            let body = try MockURLProtocol.bodyData(from: request)
            let payload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(payload["metodo"] as? String, "RFID")

            let serialId = "33333333-3333-3333-3333-333333333333"
            let data = """
            {
              "count": 1,
              "seriais": [
                { "serial_id": "\(serialId)", "codigo_interno": "MMD-ILU-0001" }
              ]
            }
            """.data(using: .utf8)!

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }

        let result = try await makeMockedClient().checkoutProject(
            projectId: projectId,
            metodoScan: .rfid
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.seriais.first?.codigoInterno, "MMD-ILU-0001")
    }

    @MainActor
    func testReturnProjectUsesSharedWebApiBoundary() async throws {
        let savedUrl = AppConfig.shared.supabaseUrl
        let savedKey = AppConfig.shared.supabaseAnonKey
        let savedWebApiUrl = AppConfig.shared.webApiUrl
        let savedWebApiAuthToken = AppConfig.shared.webApiAuthToken
        let savedUseMockRFID = AppConfig.shared.useMockRFID
        AppConfig.shared.save(
            supabaseUrl: "https://supabase.test",
            anonKey: "anon",
            webApiUrl: "https://mmd.test",
            webApiAuthToken: "access-token",
            useMockRFID: savedUseMockRFID
        )

        defer {
            AppConfig.shared.save(
                supabaseUrl: savedUrl,
                anonKey: savedKey,
                webApiUrl: savedWebApiUrl,
                webApiAuthToken: savedWebApiAuthToken,
                useMockRFID: savedUseMockRFID
            )
            MockURLProtocol.requestHandler = nil
        }

        let projectId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let serialId = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/eventos/\(projectId.uuidString)/retorno")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")

            let body = try MockURLProtocol.bodyData(from: request)
            let payload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(payload["metodo"] as? String, "RFID")

            let items = try XCTUnwrap(payload["items"] as? [[String: Any]])
            XCTAssertEqual(items.first?["serial_id"] as? String, serialId.uuidString)
            XCTAssertEqual(items.first?["resultado"] as? String, "PROBLEMA")
            XCTAssertEqual(items.first?["desgaste"] as? Int, 2)
            XCTAssertEqual(items.first?["observacao"] as? String, "Driver com ruido.")

            let data = """
            {
              "count": 1,
              "seriais": [
                {
                  "serial_id": "\(serialId.uuidString)",
                  "codigo_interno": "MMD-AUD-0002",
                  "novo_status": "MANUTENCAO"
                }
              ]
            }
            """.data(using: .utf8)!

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }

        let result = try await makeMockedClient().returnProject(
            projectId: projectId,
            metodoScan: .rfid,
            items: [
                ReturnProjectItemRequest(
                    serialId: serialId,
                    desgaste: 2,
                    resultado: .problema,
                    observacao: "Driver com ruido."
                )
            ]
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.seriais.first?.codigoInterno, "MMD-AUD-0002")
        XCTAssertEqual(result.seriais.first?.novoStatus, "MANUTENCAO")
    }

    @MainActor
    func testRecordRfidScansUsesSharedWebApiBoundary() async throws {
        let savedUrl = AppConfig.shared.supabaseUrl
        let savedKey = AppConfig.shared.supabaseAnonKey
        let savedWebApiUrl = AppConfig.shared.webApiUrl
        let savedWebApiAuthToken = AppConfig.shared.webApiAuthToken
        let savedUseMockRFID = AppConfig.shared.useMockRFID
        AppConfig.shared.save(
            supabaseUrl: "https://supabase.test",
            anonKey: "anon",
            webApiUrl: "https://mmd.test",
            webApiAuthToken: "access-token",
            useMockRFID: savedUseMockRFID
        )

        defer {
            AppConfig.shared.save(
                supabaseUrl: savedUrl,
                anonKey: savedKey,
                webApiUrl: savedWebApiUrl,
                webApiAuthToken: savedWebApiAuthToken,
                useMockRFID: savedUseMockRFID
            )
            MockURLProtocol.requestHandler = nil
        }

        let projectId = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/rfid/scans")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")

            let body = try MockURLProtocol.bodyData(from: request)
            let payload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(payload["tags"] as? [String], ["E28011702000020A5C41B6E0", "UNKNOWN1"])
            XCTAssertEqual(payload["contexto"] as? String, "CHECK_OUT_EVENTO")
            XCTAssertEqual(payload["projeto_id"] as? String, projectId.uuidString)

            let reader = try XCTUnwrap(payload["reader"] as? [String: Any])
            XCTAssertEqual(reader["nome"] as? String, "RFD40 iPhone")
            XCTAssertEqual(reader["modelo"] as? String, "Zebra RFD40")
            XCTAssertEqual(reader["serial_fabrica"] as? String, "RFD40-001")
            XCTAssertEqual(reader["bateria"] as? Int, 82)

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

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }

        let result = try await makeMockedClient().recordRfidScans(
            tags: ["E28011702000020A5C41B6E0", "UNKNOWN1"],
            contexto: .checkOutEvento,
            projectId: projectId,
            reader: RfidScanReaderRequest(
                nome: "RFD40 iPhone",
                modelo: "Zebra RFD40",
                serialFabrica: "RFD40-001",
                bateria: 82
            )
        )

        XCTAssertEqual(result.resolved.first?.codigoInterno, "MMD-ILU-0001")
        XCTAssertEqual(result.unresolved, ["UNKNOWN1"])
        XCTAssertEqual(result.scanIds.count, 1)
    }

    @MainActor
    func testRecordAndResolveRfidTagsPersistsThenFetchesFullSerials() async throws {
        let savedUrl = AppConfig.shared.supabaseUrl
        let savedKey = AppConfig.shared.supabaseAnonKey
        let savedWebApiUrl = AppConfig.shared.webApiUrl
        let savedWebApiAuthToken = AppConfig.shared.webApiAuthToken
        let savedUseMockRFID = AppConfig.shared.useMockRFID
        AppConfig.shared.save(
            supabaseUrl: "https://supabase.test",
            anonKey: "anon",
            webApiUrl: "https://mmd.test",
            webApiAuthToken: "access-token",
            useMockRFID: savedUseMockRFID
        )

        defer {
            AppConfig.shared.save(
                supabaseUrl: savedUrl,
                anonKey: savedKey,
                webApiUrl: savedWebApiUrl,
                webApiAuthToken: savedWebApiAuthToken,
                useMockRFID: savedUseMockRFID
            )
            MockURLProtocol.requestHandler = nil
        }

        let itemId = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        let serialId = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        var requests: [URLRequest] = []

        MockURLProtocol.requestHandler = { request in
            requests.append(request)

            if request.url?.host == "mmd.test" {
                let data = """
                {
                  "resolved": [
                    {
                      "tag_rfid": "E28011702000020A5C41B6E0",
                      "serial_id": "\(serialId.uuidString)",
                      "codigo_interno": "MMD-ILU-0001",
                      "item_nome": "Moving Beam 7R"
                    }
                  ],
                  "unresolved": ["UNKNOWN1"],
                  "scan_ids": ["bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"]
                }
                """.data(using: .utf8)!
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    data
                )
            }

            XCTAssertEqual(request.url?.host, "supabase.test")
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")

            let data = """
            [
              {
                "id": "\(serialId.uuidString)",
                "item_id": "\(itemId.uuidString)",
                "codigo_interno": "MMD-ILU-0001",
                "serial_fabrica": null,
                "tag_rfid": "E28011702000020A5C41B6E0",
                "qr_code": null,
                "status": "DISPONIVEL",
                "estado": "USADO",
                "desgaste": 3,
                "depreciacao_pct": null,
                "valor_atual": null,
                "localizacao": null,
                "notas": null,
                "created_at": null,
                "updated_at": null,
                "item": {
                  "id": "\(itemId.uuidString)",
                  "nome": "Moving Beam 7R",
                  "categoria": "ILUMINACAO",
                  "subcategoria": null,
                  "marca": null,
                  "modelo": null,
                  "tipo_rastreamento": "INDIVIDUAL",
                  "quantidade_total": 1,
                  "valor_mercado_unitario": null,
                  "foto_url": null,
                  "notas": null,
                  "created_at": null,
                  "updated_at": null
                }
              }
            ]
            """.data(using: .utf8)!
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                data
            )
        }

        let result = try await makeMockedClient().recordAndResolveRfidTags(
            tags: ["E28011702000020A5C41B6E0", "UNKNOWN1"],
            contexto: .checkOutEvento,
            projectId: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
            reader: nil
        )

        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(result.resolved.first?.codigoInterno, "MMD-ILU-0001")
        XCTAssertEqual(result.unresolved, ["UNKNOWN1"])
    }

    @MainActor
    func testReturnConferenceSummaryAndPayloadCoverAllOutcomes() {
        let okItem = makeReturnItem(code: "MMD-ILU-0001", result: .ok, desgaste: 4)
        let problemItem = makeReturnItem(
            code: "MMD-AUD-0002",
            result: .problema(notas: "Driver com ruido.", desgaste: 2),
            desgaste: 3
        )
        let missingItem = makeReturnItem(
            code: "MMD-CAB-0003",
            result: .naoVoltou(notas: "Nao localizado no retorno."),
            desgaste: 3
        )

        let states = [okItem, problemItem, missingItem]
        let summary = states.returnConferenceSummary
        XCTAssertEqual(summary.ok, 1)
        XCTAssertEqual(summary.problem, 1)
        XCTAssertEqual(summary.notReturned, 1)
        XCTAssertEqual(summary.pending, 0)
        XCTAssertTrue(summary.canFinalize)

        let viewModel = ReturnViewModel(
            project: makeProject(),
            apiClient: APIClient(),
            rfidManager: RFIDManager()
        )
        viewModel.outboundItems = states

        let payload = viewModel.buildReturnProjectItems()
        XCTAssertEqual(payload.map(\.resultado), [.ok, .problema, .naoVoltou])
        XCTAssertEqual(payload[1].desgaste, 2)
        XCTAssertEqual(payload[1].observacao, "Driver com ruido.")
        XCTAssertEqual(payload[2].observacao, "Nao localizado no retorno.")
    }

    func testReturnConferenceSummaryBlocksPendingItems() {
        let pendingItem = makeReturnItem(code: "MMD-EST-0004", result: .pending, desgaste: 3)
        let summary = [pendingItem].returnConferenceSummary

        XCTAssertEqual(summary.pending, 1)
        XCTAssertFalse(summary.canFinalize)
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

    private func makeProject() -> Project {
        Project(
            id: UUID(),
            nome: "Casamento Santos & Oliveira",
            cliente: "Familia Santos",
            dataInicio: "2026-06-12",
            dataFim: "2026-06-13",
            local: "Jardim Botanico, SP",
            status: .emCampo,
            notas: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func makeReturnItem(code: String, result: ReturnResult, desgaste: Int) -> ReturnItemState {
        let itemId = UUID()
        let equipment = Equipment(
            id: itemId,
            nome: "Equipamento \(code)",
            categoria: .iluminacao,
            subcategoria: nil,
            marca: nil,
            modelo: nil,
            tipoRastreamento: .individual,
            quantidadeTotal: 1,
            valorMercadoUnitario: nil,
            fotoUrl: nil,
            notas: nil,
            createdAt: nil,
            updatedAt: nil
        )
        let serial = SerialNumber(
            id: UUID(),
            itemId: itemId,
            codigoInterno: code,
            serialFabrica: nil,
            tagRfid: nil,
            qrCode: nil,
            status: .emCampo,
            estado: .usado,
            desgaste: desgaste,
            depreciacaoPct: nil,
            valorAtual: nil,
            localizacao: nil,
            notas: nil,
            createdAt: nil,
            updatedAt: nil,
            item: equipment
        )
        return ReturnItemState(
            id: serial.id,
            resolved: ResolvedItem(serialNumber: serial, equipment: equipment),
            result: result
        )
    }
}
