import SwiftUI
import Combine

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

    // MARK: - Published State

    @Published private(set) var connectionState: RFIDConnectionState = .disconnected
    @Published private(set) var discoveredReaders: [RFIDReaderInfo] = []
    @Published private(set) var scannedTags: [String] = []
    @Published private(set) var isScanning: Bool = false

    // MARK: - Computed Properties

    var isConnected: Bool { connectionState.isConnected }

    var connectedReader: RFIDReaderInfo? { connectionState.readerInfo }

    var tagCount: Int { scannedTags.count }

    // MARK: - Private

    private let implementation: RFIDReaderProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    /// Creates the RFID manager.
    ///
    /// - Parameter useMock: When `true`, uses `MockRFIDManager` regardless
    ///   of SDK availability. When `false`, uses the real Zebra SDK if
    ///   available, falling back to mock with a warning.
    init(useMock: Bool = false) {
        if useMock {
            self.implementation = MockRFIDManager()
        } else {
            #if canImport(ZebraRfidSdkFramework)
            self.implementation = ZebraRFIDManager()
            #else
            print("[RFIDManager] ZebraRfidSdkFramework not available, falling back to MockRFIDManager")
            self.implementation = MockRFIDManager()
            #endif
        }

        bindPublishers()
    }

    /// Internal init for dependency injection in tests.
    init(implementation: RFIDReaderProtocol) {
        self.implementation = implementation
        bindPublishers()
    }

    // MARK: - Publisher Bindings

    private func bindPublishers() {
        implementation.connectionStatePublisher
            .removeDuplicates()
            .assign(to: &$connectionState)

        implementation.discoveredReadersPublisher
            .assign(to: &$discoveredReaders)

        implementation.scannedTagsPublisher
            .assign(to: &$scannedTags)

        implementation.isScanningPublisher
            .removeDuplicates()
            .assign(to: &$isScanning)
    }

    // MARK: - Actions (forwarded)

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
}
