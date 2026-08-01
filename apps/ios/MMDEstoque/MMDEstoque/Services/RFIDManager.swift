import SwiftUI
import Combine

enum RFIDRuntimeMode: Equatable {
    case mock
    case zebra
    case zebraUnavailable
}

enum RFIDSDKAvailability {
    static var isZebraLinked: Bool {
        #if canImport(ZebraRfidSdkFramework)
        true
        #else
        false
        #endif
    }
}

/// Observable facade that SwiftUI views bind to.
///
/// Wraps either `ZebraRFIDManager` (when the SDK is available and not
/// running in mock mode) or `MockRFIDManager` for explicit development use.
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
    ///   of SDK availability. When `false`, uses the real Zebra SDK or an
    ///   unavailable implementation that cannot emit simulated tags.
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
        print("[RFIDManager] ZebraRfidSdkFramework not available")
        return (UnavailableRFIDManager(), .zebraUnavailable)
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
        case .zebraUnavailable:
            return "Zebra indisponível"
        }
    }
}

final class UnavailableRFIDManager: RFIDReaderProtocol {
    private let unavailableMessage = "SDK Zebra indisponível neste build"
    private let connectionStateSubject: CurrentValueSubject<RFIDConnectionState, Never>
    private let discoveredReadersSubject = CurrentValueSubject<[RFIDReaderInfo], Never>([])
    private let scannedTagsSubject = CurrentValueSubject<[String], Never>([])
    private let isScanningSubject = CurrentValueSubject<Bool, Never>(false)

    init() {
        connectionStateSubject = CurrentValueSubject(.error(unavailableMessage))
    }

    var connectionState: RFIDConnectionState { connectionStateSubject.value }
    var connectionStatePublisher: AnyPublisher<RFIDConnectionState, Never> {
        connectionStateSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    var discoveredReaders: [RFIDReaderInfo] { discoveredReadersSubject.value }
    var discoveredReadersPublisher: AnyPublisher<[RFIDReaderInfo], Never> {
        discoveredReadersSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    var scannedTags: [String] { scannedTagsSubject.value }
    var scannedTagsPublisher: AnyPublisher<[String], Never> {
        scannedTagsSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    var isScanning: Bool { isScanningSubject.value }
    var isScanningPublisher: AnyPublisher<Bool, Never> {
        isScanningSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    func discoverReaders() { publishUnavailable() }
    func connect(to reader: RFIDReaderInfo) { publishUnavailable() }
    func disconnect() { publishUnavailable() }
    func startInventory() { publishUnavailable() }
    func stopInventory() { isScanningSubject.send(false) }
    func clearTags() { scannedTagsSubject.send([]) }

    private func publishUnavailable() {
        discoveredReadersSubject.send([])
        scannedTagsSubject.send([])
        isScanningSubject.send(false)
        connectionStateSubject.send(.error(unavailableMessage))
    }
}
