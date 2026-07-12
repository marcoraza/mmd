import SwiftUI
import Combine

enum RFIDRuntimeMode: Equatable {
    case mock
    case zebra
    case zebraFallbackMock
}

enum MobileProductionGateStatus: Equatable {
    case passed
    case pending
    case blocked

    var label: String {
        switch self {
        case .passed:
            return "OK"
        case .pending:
            return "PENDENTE"
        case .blocked:
            return "BLOQUEADO"
        }
    }
}

struct MobileProductionGateEvidence: Equatable {
    let signedBuildOnDevice: Bool
    let qrFallbackValidated: Bool
    let checkoutValidated: Bool
    let returnValidated: Bool

    static let none = MobileProductionGateEvidence(
        signedBuildOnDevice: false,
        qrFallbackValidated: false,
        checkoutValidated: false,
        returnValidated: false
    )
}

struct MobileProductionGateItem: Equatable, Identifiable {
    let label: String
    let status: MobileProductionGateStatus
    let detail: String

    var id: String { label }
}

struct MobileProductionGateSnapshot: Equatable {
    let status: MobileProductionGateStatus
    let items: [MobileProductionGateItem]
    let footer: String

    static func evaluate(
        runtimeMode: RFIDRuntimeMode,
        connectionState: RFIDConnectionState,
        tagCount: Int,
        isWebApiConfigured: Bool,
        isSimulator: Bool,
        evidence: MobileProductionGateEvidence = .none
    ) -> MobileProductionGateSnapshot {
        let usingRealRFID = runtimeMode == .zebra
        let rfd40Connected = usingRealRFID && connectionState.isConnected
        let hasFiveRealTags = usingRealRFID && tagCount >= 5

        let items = [
            MobileProductionGateItem(
                label: "BUILD ASSINADO",
                status: isSimulator ? .blocked : (evidence.signedBuildOnDevice ? .passed : .pending),
                detail: isSimulator ? "Simulador" : "Validar no device"
            ),
            MobileProductionGateItem(
                label: "IPHONE REAL",
                status: isSimulator ? .blocked : .passed,
                detail: isSimulator ? "Nao conta" : "Device fisico"
            ),
            MobileProductionGateItem(
                label: "RFD40 PAREADO",
                status: usingRealRFID ? (rfd40Connected ? .passed : .pending) : .blocked,
                detail: usingRealRFID ? "Zebra SDK ativo" : runtimeMode.productionBlockerDetail
            ),
            MobileProductionGateItem(
                label: "5 TAGS REAIS",
                status: usingRealRFID ? (hasFiveRealTags ? .passed : .pending) : .blocked,
                detail: usingRealRFID ? "\(tagCount)/5 lidas" : "Mock nao conta"
            ),
            MobileProductionGateItem(
                label: "QR FALLBACK",
                status: evidence.qrFallbackValidated ? .passed : .pending,
                detail: evidence.qrFallbackValidated ? "Validado" : "Teste fisico"
            ),
            MobileProductionGateItem(
                label: "CHECKOUT WEB",
                status: isWebApiConfigured ? (evidence.checkoutValidated ? .passed : .pending) : .blocked,
                detail: isWebApiConfigured ? "API Web" : "API Web ausente"
            ),
            MobileProductionGateItem(
                label: "RETORNO WEB",
                status: isWebApiConfigured ? (evidence.returnValidated ? .passed : .pending) : .blocked,
                detail: isWebApiConfigured ? "API Web" : "API Web ausente"
            )
        ]

        return MobileProductionGateSnapshot(
            status: overallStatus(for: items),
            items: items,
            footer: footer(for: runtimeMode)
        )
    }

    private static func overallStatus(for items: [MobileProductionGateItem]) -> MobileProductionGateStatus {
        if items.contains(where: { $0.status == .blocked }) {
            return .blocked
        }

        if items.allSatisfy({ $0.status == .passed }) {
            return .passed
        }

        return .pending
    }

    private static func footer(for runtimeMode: RFIDRuntimeMode) -> String {
        switch runtimeMode {
        case .mock:
            return "Mock serve para demo, nao para campo"
        case .zebra:
            return "Validar no iPhone com RFD40 real"
        case .zebraFallbackMock:
            return "Zebra SDK ausente, app caiu em mock"
        }
    }
}

/// Observable facade that SwiftUI views bind to.
///
/// Wraps either `ZebraRFIDManager` (when the SDK is available and not
/// running in mock mode) or `MockRFIDManager` for development.
/// Views never interact with the underlying implementation directly.
///
/// Usage:
/// ```swift
/// @StateObject private var rfid = RFIDManager(useMock: true)
/// ```
final class RFIDManager: ObservableObject {

    typealias ImplementationFactory = (Bool) -> (implementation: RFIDReaderProtocol, runtimeMode: RFIDRuntimeMode)

    // MARK: - Published State

    @Published private(set) var connectionState: RFIDConnectionState = .disconnected
    @Published private(set) var discoveredReaders: [RFIDReaderInfo] = []
    @Published private(set) var scannedTags: [String] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var runtimeMode: RFIDRuntimeMode = .mock

    // MARK: - Computed Properties

    var isConnected: Bool { connectionState.isConnected }

    var connectedReader: RFIDReaderInfo? { connectionState.readerInfo }

    var tagCount: Int { scannedTags.count }

    // MARK: - Private

    private var implementation: RFIDReaderProtocol
    private let implementationFactory: ImplementationFactory
    private var sourceCancellables = Set<AnyCancellable>()
    private var requestedUseMock: Bool

    // MARK: - Init

    /// Creates the RFID manager.
    ///
    /// - Parameter useMock: When `true`, uses `MockRFIDManager` regardless
    ///   of SDK availability. When `false`, uses the real Zebra SDK if
    ///   available, falling back to mock with a warning.
    init(useMock: Bool = false, implementationFactory: @escaping ImplementationFactory = RFIDManager.resolveImplementation) {
        self.implementationFactory = implementationFactory
        self.requestedUseMock = useMock
        let resolved = implementationFactory(useMock)
        self.implementation = resolved.implementation
        self.runtimeMode = resolved.runtimeMode

        bindPublishers()
    }

    /// Internal init for dependency injection in tests.
    init(implementation: RFIDReaderProtocol) {
        self.implementationFactory = { _ in (implementation, .mock) }
        self.requestedUseMock = true
        self.implementation = implementation
        self.runtimeMode = .mock
        bindPublishers()
    }

    // MARK: - Publisher Bindings

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

        implementation.scannedTagsPublisher
            .sink { [weak self] in self?.scannedTags = $0 }
            .store(in: &sourceCancellables)

        implementation.isScanningPublisher
            .removeDuplicates()
            .sink { [weak self] in self?.isScanning = $0 }
            .store(in: &sourceCancellables)
    }

    private func refreshPublishedState() {
        connectionState = implementation.connectionState
        discoveredReaders = implementation.discoveredReaders
        scannedTags = implementation.scannedTags
        isScanning = implementation.isScanning
    }

    private static func resolveImplementation(useMock: Bool) -> (implementation: RFIDReaderProtocol, runtimeMode: RFIDRuntimeMode) {
        if useMock {
            return (MockRFIDManager(), .mock)
        }

        #if canImport(ZebraRfidSdkFramework)
        return (ZebraRFIDManager(), .zebra)
        #else
        print("[RFIDManager] ZebraRfidSdkFramework not available, falling back to MockRFIDManager")
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

    // MARK: - Actions (forwarded)

    func configure(useMock: Bool) {
        guard useMock != requestedUseMock else { return }

        requestedUseMock = useMock
        teardownCurrentImplementation()

        let resolved = implementationFactory(useMock)
        implementation = resolved.implementation
        runtimeMode = resolved.runtimeMode
        bindPublishers()
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
}

// MARK: - Convenience

extension RFIDManager {

    /// Human-readable status string for UI display.
    var statusText: String {
        switch connectionState {
        case .disconnected:
            return "Desconectado"
        case .discovering:
            return "Procurando leitores..."
        case .connecting:
            return "Conectando..."
        case .connected(let reader):
            if let battery = reader.batteryLevel {
                return "\(reader.name) (\(battery)%)"
            }
            return reader.name
        case .error(let message):
            return "Erro: \(message)"
        }
    }

    /// SF Symbol name matching the current state.
    var statusIcon: String {
        switch connectionState {
        case .disconnected:
            return "antenna.radiowaves.left.and.right.slash"
        case .discovering, .connecting:
            return "antenna.radiowaves.left.and.right"
        case .connected:
            return "antenna.radiowaves.left.and.right.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    var runtimeModeText: String {
        switch runtimeMode {
        case .mock:
            return "Simulado"
        case .zebra:
            return "Zebra SDK"
        case .zebraFallbackMock:
            return "Simulado (fallback)"
        }
    }

    var productionGateSnapshot: MobileProductionGateSnapshot {
        MobileProductionGateSnapshot.evaluate(
            runtimeMode: runtimeMode,
            connectionState: connectionState,
            tagCount: tagCount,
            isWebApiConfigured: AppConfig.shared.isWebApiConfigured,
            isSimulator: Self.isRunningOnSimulator
        )
    }

    private static var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}

private extension RFIDRuntimeMode {
    var productionBlockerDetail: String {
        switch self {
        case .mock:
            return "Modo simulado"
        case .zebra:
            return "Zebra SDK ativo"
        case .zebraFallbackMock:
            return "SDK ausente"
        }
    }
}
