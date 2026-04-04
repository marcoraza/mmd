import XCTest
import SwiftUI
@testable import MMD_Estoque

final class ThemeTests: XCTestCase {

    // MARK: - StatusSerial Color Mapping

    func testStatusSerialDisponivel() {
        XCTAssertEqual(StatusSerial.disponivel.color, .ndSuccess)
    }

    func testStatusSerialEmCampo() {
        XCTAssertEqual(StatusSerial.emCampo.color, .ndWarning)
    }

    func testStatusSerialManutencao() {
        XCTAssertEqual(StatusSerial.manutencao.color, .ndAccent)
    }

    func testStatusSerialPacked() {
        XCTAssertEqual(StatusSerial.packed.color, .ndTextDisplay)
    }

    func testStatusSerialRetornando() {
        XCTAssertEqual(StatusSerial.retornando.color, .ndInteractive)
    }

    func testStatusSerialVendido() {
        XCTAssertEqual(StatusSerial.vendido.color, .ndTextDisabled)
    }

    // MARK: - Wear Color Mapping

    func testWearColor5Excelente() {
        XCTAssertEqual(5.wearColor, .ndSuccess)
    }

    func testWearColor4Bom() {
        XCTAssertEqual(4.wearColor, .ndSuccess)
    }

    func testWearColor3Regular() {
        XCTAssertEqual(3.wearColor, .ndTextDisplay)
    }

    func testWearColor2Desgastado() {
        XCTAssertEqual(2.wearColor, .ndWarning)
    }

    func testWearColor1Critico() {
        XCTAssertEqual(1.wearColor, .ndAccent)
    }

    func testWearColorOutOfRange() {
        XCTAssertEqual(0.wearColor, .ndTextDisabled)
        XCTAssertEqual(6.wearColor, .ndTextDisabled)
    }

    // MARK: - Categoria Prefix

    func testCategoriaIluminacaoPrefix() {
        XCTAssertEqual(Categoria.iluminacao.prefix, "ILU")
    }

    func testCategoriaAudioPrefix() {
        XCTAssertEqual(Categoria.audio.prefix, "AUD")
    }

    func testCategoriaCaboPrefix() {
        XCTAssertEqual(Categoria.cabo.prefix, "CAB")
    }

    // MARK: - StatusProjeto Color

    func testStatusProjetoConfirmado() {
        XCTAssertEqual(StatusProjeto.confirmado.color, .ndSuccess)
    }

    func testStatusProjetoEmCampo() {
        XCTAssertEqual(StatusProjeto.emCampo.color, .ndWarning)
    }

    func testStatusProjetoCancelado() {
        XCTAssertEqual(StatusProjeto.cancelado.color, .ndAccent)
    }

    func testStatusProjetoPlanejamento() {
        XCTAssertEqual(StatusProjeto.planejamento.color, .ndTextSecondary)
    }

    func testStatusProjetoFinalizado() {
        XCTAssertEqual(StatusProjeto.finalizado.color, .ndTextDisabled)
    }

    // MARK: - TipoMovimentacao Color

    func testTipoMovimentacaoSaida() {
        XCTAssertEqual(TipoMovimentacao.saida.color, .ndWarning)
    }

    func testTipoMovimentacaoRetorno() {
        XCTAssertEqual(TipoMovimentacao.retorno.color, .ndSuccess)
    }

    func testTipoMovimentacaoDano() {
        XCTAssertEqual(TipoMovimentacao.dano.color, .ndAccent)
    }

    // MARK: - Hex Color Initializer

    func testHexColorBlack() {
        let color = Color(hex: 0x000000)
        XCTAssertNotNil(color)
    }

    func testHexColorWhite() {
        let color = Color(hex: 0xFFFFFF)
        XCTAssertNotNil(color)
    }

    func testHexColorAccent() {
        let color = Color(hex: 0xD71921)
        XCTAssertNotNil(color)
    }
}
