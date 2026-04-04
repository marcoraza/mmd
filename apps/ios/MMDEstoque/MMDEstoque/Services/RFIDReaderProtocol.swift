import Foundation
import Combine

// MARK: - Reader Info

/// Hardware-agnostic representation of an RFID reader.
/// Decoupled from any specific SDK so the rest of the app never
/// imports vendor frameworks directly.
struct RFIDReaderInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let serialNumber: String?
    let batteryLevel: Int?  // 0-100, nil if unknown
}

// MARK: - Connection State

enum RFIDConnectionState: Equatable {
    case disconnected
    case discovering
    case connecting
    case connected(RFIDReaderInfo)
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var readerInfo: RFIDReaderInfo? {
        if case .connected(let info) = self { return info }
        return nil
    }

    // Equatable conformance for the error case
    static func == (lhs: RFIDConnectionState, rhs: RFIDConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected):
            return true
        case (.discovering, .discovering):
            return true
        case (.connecting, .connecting):
            return true
        case (.connected(let a), .connected(let b)):
            return a == b
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Protocol

/// Contract for any RFID reader implementation (real hardware or mock).
///
/// All publishers emit on the main queue. Implementations must guarantee
/// that state transitions are serialized and consistent.
protocol RFIDReaderProtocol: AnyObject {

    // MARK: State

    var connectionState: RFIDConnectionState { get }
    var connectionStatePublisher: AnyPublisher<RFIDConnectionState, Never> { get }

    var discoveredReaders: [RFIDReaderInfo] { get }
    var discoveredReadersPublisher: AnyPublisher<[RFIDReaderInfo], Never> { get }

    /// Unique EPC tag identifiers collected during the current inventory session.
    var scannedTags: [String] { get }
    var scannedTagsPublisher: AnyPublisher<[String], Never> { get }

    var isScanning: Bool { get }
    var isScanningPublisher: AnyPublisher<Bool, Never> { get }

    // MARK: Actions

    /// Start searching for available readers (Bluetooth/MFi).
    func discoverReaders()

    /// Connect to a specific reader. State will transition through
    /// `.connecting` then `.connected` or `.error`.
    func connect(to reader: RFIDReaderInfo)

    /// Disconnect from the current reader and return to `.disconnected`.
    func disconnect()

    /// Begin an RFID inventory (rapid read). Tags appear in `scannedTags`.
    func startInventory()

    /// Stop the current inventory scan.
    func stopInventory()

    /// Clear the accumulated tag list without stopping the scan.
    func clearTags()
}
