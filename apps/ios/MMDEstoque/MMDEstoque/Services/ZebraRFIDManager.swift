#if canImport(ZebraRfidSdkFramework)
import Foundation
import Combine
import ZebraRfidSdkFramework

/// Production RFID implementation using the Zebra iOS RFID SDK.
///
/// The RFD40 reader connects via External Accessory (MFi Bluetooth),
/// not standard BLE. The SDK communicates through a delegate-based
/// Objective-C API (`srfidISdkApiDelegate`).
///
/// This class bridges the delegate callbacks into Combine publishers
/// so the SwiftUI layer stays reactive and SDK-free.
final class ZebraRFIDManager: NSObject, RFIDReaderProtocol {

    // MARK: - Combine Subjects

    private let connectionStateSubject = CurrentValueSubject<RFIDConnectionState, Never>(.disconnected)
    private let discoveredReadersSubject = CurrentValueSubject<[RFIDReaderInfo], Never>([])
    private let scannedTagsSubject = CurrentValueSubject<[String], Never>([])
    private let isScanningSubject = CurrentValueSubject<Bool, Never>(false)

    // MARK: - RFIDReaderProtocol (published state)

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

    // MARK: - SDK References

    /// Strong reference to the Zebra SDK API singleton.
    /// TODO: Verify initialization method against SDK docs — may be
    /// `srfidSdkFactory.createRfidSdkApiInstance()` or similar.
    private var sdkApi: srfidISdkApi?

    /// Reader ID returned by the SDK after connection. Needed for
    /// inventory start/stop and disconnect calls.
    private var connectedReaderId: Int32 = -1

    /// Set of EPC strings for O(1) deduplication during rapid reads.
    private var tagSet = Set<String>()

    // MARK: - Init

    override init() {
        super.init()

        // TODO: Verify exact factory method from SDK headers.
        // The SDK typically provides a shared instance or factory.
        sdkApi = srfidSdkFactory.createRfidSdkApiInstance()
        sdkApi?.srfidSetDelegate(self)

        // Subscribe to all event groups we care about.
        // TODO: Verify bitmask values against SDK headers.
        let notifications: Int32 = CYCLOPSEVENT_READER_APPEARED
            | CYCLOPSEVENT_READER_DISAPPEARED
            | CYCLOPSEVENT_SESSION_ESTABLISHMENT
            | CYCLOPSEVENT_SESSION_TERMINATION
            | CYCLOPSEVENT_READ_NOTIFY
            | CYCLOPSEVENT_STATUS_NOTIFY
            | CYCLOPSEVENT_PROXIMITY_NOTIFY

        sdkApi?.srfidSubsribeForEvents(notifications)
        sdkApi?.srfidSetOperationalMode(Int32(CYCLOPSEVENT_MODE_MFI))
    }

    // MARK: - RFIDReaderProtocol (actions)

    func discoverReaders() {
        discoveredReadersSubject.send([])
        connectionStateSubject.send(.discovering)

        // SDK auto-detection should surface readers via delegate.
        // TODO: Verify if explicit call is needed or if subscribing
        // to CYCLOPSEVENT_READER_APPEARED is sufficient.
        sdkApi?.srfidEnableAvailableReadersDetection(true)
    }

    func connect(to reader: RFIDReaderInfo) {
        guard let readerId = Int32(reader.id) else {
            connectionStateSubject.send(.error("ID de leitor invalido: \(reader.id)"))
            return
        }

        connectionStateSubject.send(.connecting)

        // TODO: Verify parameter list — some SDK versions take a password.
        let result = sdkApi?.srfidEstablishCommunicationSession(readerId)

        if result != CYCLOPSEVENT_STATUS_SUCCESS {
            connectionStateSubject.send(.error("Falha ao conectar ao leitor (codigo: \(result ?? -1))"))
        }
        // On success the delegate callback handles the state transition.
    }

    func disconnect() {
        guard connectedReaderId >= 0 else { return }

        if isScanning {
            stopInventory()
        }

        sdkApi?.srfidTerminateCommunicationSession(connectedReaderId)
        connectedReaderId = -1
        connectionStateSubject.send(.disconnected)
    }

    func startInventory() {
        guard connectedReaderId >= 0 else { return }
        guard !isScanning else { return }

        // TODO: Verify method name — could be srfidStartRapidRead or
        // srfidStartInventory depending on SDK version.
        let result = sdkApi?.srfidStartRapidRead(connectedReaderId, aStatusMessage: nil)

        if result == CYCLOPSEVENT_STATUS_SUCCESS {
            isScanningSubject.send(true)
        } else {
            connectionStateSubject.send(.error("Falha ao iniciar leitura (codigo: \(result ?? -1))"))
        }
    }

    func stopInventory() {
        guard connectedReaderId >= 0 else { return }

        // TODO: Match start method — srfidStopRapidRead or srfidStopInventory.
        sdkApi?.srfidStopRapidRead(connectedReaderId, aStatusMessage: nil)
        isScanningSubject.send(false)
    }

    func clearTags() {
        tagSet.removeAll()
        scannedTagsSubject.send([])
    }

    // MARK: - Helpers

    /// Add a tag EPC if not already seen, then publish the updated list.
    private func addTagIfNew(_ epc: String) {
        let trimmed = epc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }

        if tagSet.insert(trimmed).inserted {
            scannedTagsSubject.send(Array(tagSet).sorted())
        }
    }
}

// MARK: - srfidISdkApiDelegate

extension ZebraRFIDManager: srfidISdkApiDelegate {

    // Reader discovered via MFi/Bluetooth
    func srfidEventReaderAppeared(_ availableReader: srfidReaderInfo!) {
        guard let reader = availableReader else { return }

        let info = RFIDReaderInfo(
            id: String(reader.getReaderID()),
            name: reader.getReaderName() ?? "Zebra RFD40",
            serialNumber: nil,  // TODO: Fetch via srfidGetReaderInfo after connection
            batteryLevel: nil
        )

        var current = discoveredReadersSubject.value
        if !current.contains(where: { $0.id == info.id }) {
            current.append(info)
            discoveredReadersSubject.send(current)
        }
    }

    // Reader disconnected / went out of range
    func srfidEventReaderDisappeared(_ readerID: Int32) {
        var current = discoveredReadersSubject.value
        current.removeAll { $0.id == String(readerID) }
        discoveredReadersSubject.send(current)

        if connectedReaderId == readerID {
            connectedReaderId = -1
            isScanningSubject.send(false)
            connectionStateSubject.send(.error("Leitor desconectado inesperadamente"))
        }
    }

    // Connection established
    func srfidEventCommunicationSessionEstablished(_ activeReader: srfidReaderInfo!) {
        guard let reader = activeReader else { return }

        connectedReaderId = reader.getReaderID()

        // TODO: Query battery level via srfidGetReaderInfo / srfidGetBatteryStats
        let info = RFIDReaderInfo(
            id: String(reader.getReaderID()),
            name: reader.getReaderName() ?? "Zebra RFD40",
            serialNumber: nil,
            batteryLevel: nil
        )

        connectionStateSubject.send(.connected(info))
    }

    // Connection terminated
    func srfidEventCommunicationSessionTerminated(_ readerID: Int32) {
        if connectedReaderId == readerID {
            connectedReaderId = -1
            isScanningSubject.send(false)
            connectionStateSubject.send(.disconnected)
        }
    }

    // Tag read during inventory
    func srfidEventReadNotify(_ readerID: Int32, aTagData tagData: srfidTagData!) {
        guard let tag = tagData else { return }

        // TODO: Verify method name — could be getTagId, getEPC, etc.
        if let epc = tag.getTagId() {
            addTagIfNew(epc)
        }
    }

    // Status notification (battery, temperature, etc.)
    func srfidEventStatusNotify(_ readerID: Int32, aEvent event: CYCLOPSEVENT_TYPE, aNotification notification: Any!) {
        // TODO: Handle battery updates and reader status changes.
        // Parse notification based on event type to update reader info.
    }

    // Proximity notification (locate mode)
    func srfidEventProximityNotify(_ readerID: Int32, aProximityPercent proximityPercent: Int32) {
        // Not used in inventory flow. Reserved for future "find tag" feature.
    }

    // Trigger event (gun trigger on sled readers)
    func srfidEventTriggerNotify(_ readerID: Int32, aTriggerEvent triggerEvent: CYCLOPSEVENT_TYPE) {
        // Map trigger press to start/stop inventory for hands-free operation.
        switch triggerEvent {
        case CYCLOPSEVENT_TRIGGER_PRESSED:
            if !isScanning { startInventory() }
        case CYCLOPSEVENT_TRIGGER_RELEASED:
            if isScanning { stopInventory() }
        default:
            break
        }
    }
}

#endif
