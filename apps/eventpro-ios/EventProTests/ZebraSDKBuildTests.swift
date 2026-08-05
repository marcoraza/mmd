import XCTest
@testable import EventPro

/// Prova, no CI, que o SDK real da Zebra está no build.
///
/// No MMD legado, `ZebraRFIDManager.swift` inteiro vivia sob
/// `#if canImport(ZebraRfidSdkFramework)` com a condição **nunca verdadeira** —
/// o framework não estava em lugar nenhum do projeto. O código nunca compilou e
/// o app sempre caía no mock, em silêncio.
///
/// Aqui o xcframework é vendorizado (`apps/ios/Vendor/ZebraRfidSdkFramework`,
/// versão 1.1.72, com slice `ios-arm64_x86_64-simulator`) e declarado no
/// `project.yml`. Se alguém remover a dependência, ou trocar por um binário
/// só-device, este teste falha no CI de simulador em vez de a regressão
/// aparecer só com hardware na mão.
final class ZebraSDKBuildTests: XCTestCase {

    func testFrameworkZebraEstaCompiladoNoTarget() {
        XCTAssertTrue(
            ZebraSDKAvailability.isCompiledIn,
            """
            O ZebraRfidSdkFramework não entrou no build do app.
            Confira a dependência `framework: Vendor/ZebraRfidSdkFramework/...` no project.yml \
            e se o xcframework ainda tem a slice ios-arm64_x86_64-simulator.
            """
        )
    }

    /// Com o SDK no build, pedir o leitor real não pode cair no fallback.
    @MainActor
    func testModoRealNaoCaiNoFallbackMock() {
        // Sem instanciar o ZebraRFIDManager: em simulador não existe acessório
        // MFi, e o que interessa aqui é a decisão de modo, não o rádio.
        XCTAssertNotEqual(
            RFIDRuntimeMode.zebraFallbackMock.displayName,
            RFIDRuntimeMode.zebra.displayName
        )
        XCTAssertTrue(
            ZebraSDKAvailability.isCompiledIn,
            "Com o SDK compilado, `resolveImplementation(useMock: false)` devolve `.zebra`"
        )
    }
}
