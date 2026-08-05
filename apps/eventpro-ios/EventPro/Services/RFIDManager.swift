import Foundation
import Combine

enum RFIDRuntimeMode: Equatable {
    /// Simulado por escolha do operador.
    case mock
    /// SDK Zebra real.
    case zebra
    /// Pediu real, mas o SDK não está no build. Transitório: com o
    /// `ZebraRfidSdkFramework.xcframework` vendorizado em `Vendor/`, esse caso
    /// só aparece se alguém remover a dependência do `project.yml`.
    case zebraFallbackMock

    var displayName: String {
        switch self {
        case .mock: return "Simulado"
        case .zebra: return "Zebra SDK"
        case .zebraFallbackMock: return "Simulado (fallback)"
        }
    }
}

/// Fachada observável a que as views SwiftUI se ligam.
///
/// Envolve `ZebraRFIDManager` (SDK real) ou `MockRFIDManager`. As views nunca
/// falam com a implementação diretamente e nunca importam o SDK.
@MainActor
final class RFIDManager: ObservableObject {

    typealias ImplementationFactory = (Bool) -> (implementation: RFIDReaderProtocol, runtimeMode: RFIDRuntimeMode)

    // MARK: - Published State

    @Published private(set) var connectionState: RFIDConnectionState = .disconnected
    @Published private(set) var discoveredReaders: [RFIDReaderInfo] = []

    /// Leituras na ordem de chegada.
    @Published private(set) var tagReads: [RFIDTagRead] = []

    @Published private(set) var isScanning: Bool = false
    @Published private(set) var batteryLevel: Int?
    @Published private(set) var lastError: RFIDReaderError?
    @Published private(set) var runtimeMode: RFIDRuntimeMode = .mock

    // MARK: - Derivados

    var isConnected: Bool { connectionState.isConnected }

    var connectedReader: RFIDReaderInfo? {
        connectionState.readerInfo?.withBattery(batteryLevel ?? connectionState.readerInfo?.batteryLevel)
    }

    /// EPCs normalizados, na ordem de leitura.
    var scannedTags: [String] { tagReads.map(\.tag) }

    /// Última tag lida por ordem de chegada. É o que a tela de vincular usa.
    var lastReadTag: String? { tagReads.last?.tag }

    /// Mapa tag -> RSSI de pico, pronto para `rssi_por_tag`.
    var rssiByTag: [String: Int] {
        var out: [String: Int] = [:]
        for read in tagReads where read.rssi != nil {
            out[read.tag] = read.rssi
        }
        return out
    }

    var tagCount: Int { tagReads.count }

    // MARK: - Private

    private var implementation: RFIDReaderProtocol
    private let implementationFactory: ImplementationFactory
    private var sourceCancellables = Set<AnyCancellable>()
    private var requestedUseMock: Bool

    // MARK: - Init

    /// - Parameter useMock: `true` força o simulado. `false` usa o SDK Zebra
    ///   quando disponível, caindo para o simulado com aviso.
    init(
        useMock: Bool = false,
        implementationFactory: @escaping ImplementationFactory = RFIDManager.resolveImplementation
    ) {
        self.implementationFactory = implementationFactory
        self.requestedUseMock = useMock
        let resolved = implementationFactory(useMock)
        self.implementation = resolved.implementation
        self.runtimeMode = resolved.runtimeMode
        bindPublishers()
        applyStoredAntennaPower()
    }

    /// Injeção direta, para testes.
    init(implementation: RFIDReaderProtocol) {
        self.implementationFactory = { _ in (implementation, .mock) }
        self.requestedUseMock = true
        self.implementation = implementation
        self.runtimeMode = .mock
        bindPublishers()
    }

    // MARK: - Bindings

    private func bindPublishers() {
        sourceCancellables.removeAll()
        refreshPublishedState()

        implementation.connectionStatePublisher
            .removeDuplicates()
            .sink { [weak self] in self?.connectionState = $0 }
            .store(in: &sourceCancellables)

        implementation.discoveredReadersPublisher
            .sink { [weak self] in self?.discoveredReaders = $0 }
            .store(in: &sourceCancellables)

        implementation.tagReadsPublisher
            .sink { [weak self] in self?.tagReads = $0 }
            .store(in: &sourceCancellables)

        implementation.isScanningPublisher
            .removeDuplicates()
            .sink { [weak self] in self?.isScanning = $0 }
            .store(in: &sourceCancellables)

        implementation.batteryLevelPublisher
            .removeDuplicates()
            .sink { [weak self] in self?.batteryLevel = $0 }
            .store(in: &sourceCancellables)

        implementation.lastErrorPublisher
            .removeDuplicates()
            .sink { [weak self] in self?.lastError = $0 }
            .store(in: &sourceCancellables)
    }

    private func refreshPublishedState() {
        connectionState = implementation.connectionState
        discoveredReaders = implementation.discoveredReaders
        tagReads = implementation.tagReads
        isScanning = implementation.isScanning
        batteryLevel = implementation.batteryLevel
        lastError = implementation.lastError
    }

    nonisolated private static func resolveImplementation(
        useMock: Bool
    ) -> (implementation: RFIDReaderProtocol, runtimeMode: RFIDRuntimeMode) {
        if useMock {
            return (MockRFIDManager(), .mock)
        }

        #if canImport(ZebraRfidSdkFramework)
        return (ZebraRFIDManager(), .zebra)
        #else
        // Transitório e agora documentado: o xcframework está vendorizado em
        // apps/ios/Vendor e declarado no project.yml, então este ramo só existe
        // para quem remover a dependência.
        return (MockRFIDManager(), .zebraFallbackMock)
        #endif
    }

    private func teardownCurrentImplementation() {
        if implementation.isScanning {
            implementation.stopInventory()
        }
        implementation.disconnect()
        implementation.clearTags()
        sourceCancellables.removeAll()
    }

    private func applyStoredAntennaPower() {
        implementation.setAntennaPower(deciDbm: AppConfig.shared.antennaPowerDeciDbm)
    }

    // MARK: - Ações

    func configure(useMock: Bool) {
        guard useMock != requestedUseMock else { return }

        requestedUseMock = useMock
        teardownCurrentImplementation()

        let resolved = implementationFactory(useMock)
        implementation = resolved.implementation
        runtimeMode = resolved.runtimeMode
        bindPublishers()
        applyStoredAntennaPower()
    }

    func discoverReaders() {
        implementation.discoverReaders()
    }

    func connect(to reader: RFIDReaderInfo) {
        implementation.connect(to: reader)
    }

    func disconnect() {
        implementation.disconnect()
    }

    func startInventory() {
        implementation.startInventory()
    }

    func stopInventory() {
        implementation.stopInventory()
    }

    func clearTags() {
        implementation.clearTags()
    }

    func refreshBattery() {
        implementation.refreshBattery()
    }

    func clearError() {
        implementation.clearError()
    }

    /// Ajusta a potência e persiste a escolha.
    func setAntennaPower(deciDbm: Int) {
        let clamped = min(AppConfig.maxAntennaPowerDeciDbm, max(AppConfig.minAntennaPowerDeciDbm, deciDbm))
        AppConfig.shared.antennaPowerDeciDbm = clamped
        implementation.setAntennaPower(deciDbm: clamped)
    }

    /// Payload de leitor para os endpoints de scan e conferência.
    func readerRequest() -> RfidScanReaderRequest? {
        guard let reader = connectedReader else { return nil }
        return RfidScanReaderRequest(
            nome: reader.name,
            modelo: "Zebra RFD40",
            serialFabrica: reader.serialNumber,
            bateria: reader.batteryLevel
        )
    }
}

// MARK: - Conveniências de UI

extension RFIDManager {

    var statusText: String {
        switch connectionState {
        case .disconnected:
            return lastError?.errorDescription ?? "Desconectado"
        case .discovering:
            return "Procurando leitores..."
        case .connecting:
            return "Conectando..."
        case .connected(let reader):
            if let battery = batteryLevel ?? reader.batteryLevel {
                return "\(reader.name) (\(battery)%)"
            }
            return reader.name
        }
    }

    var statusIcon: String {
        if lastError != nil, !connectionState.isConnected {
            return "exclamationmark.triangle.fill"
        }
        switch connectionState {
        case .disconnected:
            return "antenna.radiowaves.left.and.right.slash"
        case .discovering, .connecting:
            return "antenna.radiowaves.left.and.right"
        case .connected:
            return "antenna.radiowaves.left.and.right.circle.fill"
        }
    }

    var runtimeModeText: String { runtimeMode.displayName }
}
