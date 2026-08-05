import XCTest
@testable import EventPro

/// Divergência D1 de `docs/contratos-api.md` (bloqueante no legado):
/// o app não conseguia completar um retorno que a RPC aceitasse, porque
/// descartava os itens pendentes e nunca produzia `NAO_VOLTOU`.
@MainActor
final class ReturnViewModelTests: XCTestCase {

    // MARK: - Fixtures

    private func makeEquipment() -> Equipment {
        Equipment(
            id: UUID(),
            nome: "Moving Head Beam 230",
            categoria: .iluminacao,
            marca: "Elation",
            modelo: "Platinum Beam"
        )
    }

    private func makeItem(codigo: String, desgaste: Int = 4) -> ReturnItemState {
        let equipment = makeEquipment()
        let serial = SerialNumber(
            id: UUID(),
            itemId: equipment.id,
            codigoInterno: codigo,
            status: .emCampo,
            estado: .usado,
            desgaste: desgaste
        )
        return ReturnItemState(
            id: serial.id,
            resolved: ResolvedItem(serialNumber: serial, equipment: equipment)
        )
    }

    private func makeViewModel(items: [ReturnItemState]) -> ReturnViewModel {
        let project = Project(id: UUID(), nome: "Festival Verão 2026", status: .emCampo)
        let viewModel = ReturnViewModel(
            project: project,
            apiClient: APIClient(),
            rfidManager: RFIDManager(implementation: MockRFIDManager())
        )
        viewModel.replaceOutboundItems(items)
        return viewModel
    }

    // MARK: - D1: cobertura total

    func testPayloadCobreTodasAsUnidades() {
        let items = [makeItem(codigo: "MMD-ILU-0001"), makeItem(codigo: "MMD-ILU-0002"), makeItem(codigo: "MMD-AUD-0012")]
        let viewModel = makeViewModel(items: items)

        viewModel.markAsOK(serialId: items[0].id)
        // items[1] e items[2] ficam pendentes de propósito.

        let payload = viewModel.buildReturnProjectItems()

        XCTAssertEqual(
            payload.count,
            items.count,
            "A RPC exige cobertura total: nenhum item pode sumir do payload"
        )
        XCTAssertEqual(
            Set(payload.map(\.serialId)),
            Set(items.map(\.id))
        )
    }

    func testItemPendenteViraNaoVoltouExplicito() {
        let items = [makeItem(codigo: "MMD-ILU-0001"), makeItem(codigo: "MMD-ILU-0002")]
        let viewModel = makeViewModel(items: items)

        viewModel.markAsOK(serialId: items[0].id)

        let payload = viewModel.buildReturnProjectItems()
        let pendente = payload.first { $0.serialId == items[1].id }

        XCTAssertEqual(pendente?.resultado, .naoVoltou)
        XCTAssertNotNil(pendente?.observacao, "O motivo do NAO_VOLTOU automático precisa ficar registrado")
    }

    func testNaoVoltouMarcadoExplicitamenteNaoGanhaObservacaoAutomatica() {
        let item = makeItem(codigo: "MMD-CAB-0044")
        let viewModel = makeViewModel(items: [item])

        viewModel.markAsNaoVoltou(serialId: item.id)

        let payload = viewModel.buildReturnProjectItems()
        XCTAssertEqual(payload.first?.resultado, .naoVoltou)
        XCTAssertNil(payload.first?.observacao)
    }

    func testTodosOsDesfechosDoContratoSaoAlcancaveis() {
        let items = [
            makeItem(codigo: "MMD-ILU-0001"),
            makeItem(codigo: "MMD-ILU-0002"),
            makeItem(codigo: "MMD-ILU-0003"),
        ]
        let viewModel = makeViewModel(items: items)

        viewModel.markAsOK(serialId: items[0].id)
        XCTAssertTrue(
            viewModel.markAsProblema(serialId: items[1].id, observacao: "Lente trincada", desgaste: 2)
        )
        viewModel.markAsNaoVoltou(serialId: items[2].id)

        let resultados = viewModel.buildReturnProjectItems().map(\.resultado)
        XCTAssertEqual(Set(resultados), Set(ReturnProjectOutcome.allCases))
    }

    // MARK: - Confirmação de pendentes

    func testRequerConfirmacaoQuandoSobraPendente() {
        let items = [makeItem(codigo: "MMD-ILU-0001"), makeItem(codigo: "MMD-ILU-0002")]
        let viewModel = makeViewModel(items: items)
        viewModel.markAsOK(serialId: items[0].id)

        XCTAssertEqual(viewModel.pendenteCount, 1)
        XCTAssertTrue(viewModel.requerConfirmacaoDePendentes)
        XCTAssertEqual(viewModel.itensQueViraoNaoVoltou.map(\.id), [items[1].id])
    }

    func testNaoRequerConfirmacaoQuandoTudoFoiConferido() {
        let items = [makeItem(codigo: "MMD-ILU-0001")]
        let viewModel = makeViewModel(items: items)
        viewModel.markAsOK(serialId: items[0].id)

        XCTAssertFalse(viewModel.requerConfirmacaoDePendentes)
    }

    func testFinalizarSemConfirmarPendentesEhRecusado() async {
        let items = [makeItem(codigo: "MMD-ILU-0001")]
        let viewModel = makeViewModel(items: items)

        await viewModel.finalizeReturn(confirmarPendentesComoNaoVoltou: false)

        XCTAssertFalse(viewModel.returnComplete)
        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.error?.contains("não conferida") ?? false)
    }

    // MARK: - Observação e desgaste

    func testProblemaExigeObservacaoDeTresCaracteres() {
        let item = makeItem(codigo: "MMD-AUD-0012")
        let viewModel = makeViewModel(items: [item])

        XCTAssertFalse(viewModel.markAsProblema(serialId: item.id, observacao: "ok", desgaste: 3))
        XCTAssertNotNil(viewModel.error)
        XCTAssertEqual(viewModel.problemaCount, 0)

        XCTAssertTrue(viewModel.markAsProblema(serialId: item.id, observacao: "mau contato", desgaste: 3))
        XCTAssertEqual(viewModel.problemaCount, 1)
    }

    func testObservacaoDeProblemaEhTruncadaEm240() {
        let item = makeItem(codigo: "MMD-AUD-0012")
        let viewModel = makeViewModel(items: [item])
        let longa = String(repeating: "x", count: 500)

        XCTAssertTrue(viewModel.markAsProblema(serialId: item.id, observacao: longa, desgaste: 3))

        let payload = viewModel.buildReturnProjectItems()
        XCTAssertEqual(payload.first?.observacao?.count, 240)
    }

    func testDesgasteEhLimitadoEntreUmECinco() {
        XCTAssertEqual(ReturnViewModel.clampDesgaste(0), 1)
        XCTAssertEqual(ReturnViewModel.clampDesgaste(9), 5)
        XCTAssertEqual(ReturnViewModel.clampDesgaste(3), 3)
    }

    func testDesgasteDoItemOkVemDoSerial() {
        let item = makeItem(codigo: "MMD-ILU-0001", desgaste: 5)
        let viewModel = makeViewModel(items: [item])
        viewModel.markAsOK(serialId: item.id)

        XCTAssertEqual(viewModel.buildReturnProjectItems().first?.desgaste, 5)
    }

    // MARK: - Desfazer

    func testResetItemVoltaParaPendente() {
        let item = makeItem(codigo: "MMD-ILU-0001")
        let viewModel = makeViewModel(items: [item])

        viewModel.markAsOK(serialId: item.id)
        XCTAssertEqual(viewModel.okCount, 1)

        viewModel.resetItem(serialId: item.id)
        XCTAssertEqual(viewModel.okCount, 0)
        XCTAssertEqual(viewModel.pendenteCount, 1)
    }

    // MARK: - Mapa de desfecho

    func testOutcomeDeCadaResultado() {
        XCTAssertEqual(ReturnResult.ok.outcome, .ok)
        XCTAssertEqual(ReturnResult.problema(observacao: "x", desgaste: 1).outcome, .problema)
        XCTAssertEqual(ReturnResult.naoVoltou.outcome, .naoVoltou)
        XCTAssertEqual(ReturnResult.pendente.outcome, .naoVoltou)
    }

    func testDestinoDeCadaDesfechoEspelhaOServidor() {
        XCTAssertEqual(ReturnProjectOutcome.ok.novoStatus, .disponivel)
        XCTAssertEqual(ReturnProjectOutcome.problema.novoStatus, .manutencao)
        XCTAssertEqual(ReturnProjectOutcome.naoVoltou.novoStatus, .retornando)

        XCTAssertFalse(ReturnProjectOutcome.ok.abrePendencia)
        XCTAssertFalse(ReturnProjectOutcome.problema.abrePendencia)
        XCTAssertTrue(ReturnProjectOutcome.naoVoltou.abrePendencia)
    }
}
