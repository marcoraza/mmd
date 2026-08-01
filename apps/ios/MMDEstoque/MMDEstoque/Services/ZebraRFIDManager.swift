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
    private var sdkApi: srfidISdkApi?

    /// Reader ID returned by the SDK after connection. Needed for
    /// inventory start/stop and disconnect calls.
    private var connectedReaderId: Int32 = -1

    /// Set of EPC strings for O(1) deduplication during rapid reads.
    private var tagSet = Set<String>()

    // MARK: - Init

    override init() {
        super.init()

        sdkApi = srfidSdkFactory.createRfidSdkApiInstance()
        sdkApi?.srfidSetDelegate(self)

        // Subscribe to all event groups we care about.
        let notifications = SRFID_EVENT_READER_APPEARANCE
            | SRFID_EVENT_READER_DISAPPEARANCE
            | SRFID_EVENT_SESSION_ESTABLISHMENT
            | SRFID_EVENT_SESSION_TERMINATION
            | SRFID_EVENT_MASK_READ
            | SRFID_EVENT_MASK_STATUS
            | SRFID_EVENT_MASK_PROXIMITY
            | SRFID_EVENT_MASK_TRIGGER
            | SRFID_EVENT_MASK_BATTERY

        sdkApi?.srfidSubsribe(forEvents: Int32(notifications))
        sdkApi?.srfidSetOperationalMode(Int32(SRFID_OPMODE_MFI))
    }

    // MARK: - RFIDReaderProtocol (actions)

    func discoverReaders() {
        discoveredReadersSubject.send([])
        connectionStateSubject.send(.discovering)

        sdkApi?.srfidEnableAvailableReadersDetection(true)
    }

    func connect(to reader: RFIDReaderInfo) {
        guard let readerId = Int32(reader.id) else {
            connectionStateSubject.send(.error("ID de leitor invalido: \(reader.id)"))
            return
        }

        connectionStateSubject.send(.connecting)

        let result = sdkApi?.srfidEstablishCommunicationSession(readerId)

        if result != SRFID_RESULT_SUCCESS {
            connectionStateSubject.send(.error("Falha ao conectar ao leitor"))
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

        let reportConfig = srfidReportConfig()
        let accessConfig = srfidAccessConfig()
        var statusMessage: NSString?
        let result = sdkApi?.srfidStartRapidRead(
            connectedReaderId,
            aReportConfig: reportConfig,
            aAccessConfig: accessConfig,
            aStatusMessage: &statusMessage
        )

        if result == SRFID_RESULT_SUCCESS {
            isScanningSubject.send(true)
        } else {
            let detail = statusMessage.map(String.init) ?? "sem detalhe do leitor"
            connectionStateSubject.send(.error("Falha ao iniciar leitura: \(detail)"))
        }
    }

    func stopInventory() {
        guard connectedReaderId >= 0 else { return }

        var statusMessage: NSString?
        let result = sdkApi?.srfidStopRapidRead(connectedReaderId, aStatusMessage: &statusMessage)

        if result == SRFID_RESULT_SUCCESS {
            isScanningSubject.send(false)
        } else {
            let detail = statusMessage.map(String.init) ?? "sem detalhe do leitor"
            connectionStateSubject.send(.error("Falha ao parar leitura: \(detail)"))
        }
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
            serialNumber: nil,
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

        let info = RFIDReaderInfo(
            id: String(reader.getReaderID()),
            name: reader.getReaderName() ?? "Zebra RFD40",
            serialNumber: nil,
            batteryLevel: nil
        )

        connectionStateSubject.send(.connected(info))
        sdkApi?.srfidRequestBatteryStatus(connectedReaderId)
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

        if let epc = tag.getTagId() {
            addTagIfNew(epc)
        }
    }

    // Status notification (battery, temperature, etc.)
    func srfidEventStatusNotify(_ readerID: Int32, aEvent event: SRFID_EVENT_STATUS, aNotification notification: Any!) {
        if event == SRFID_EVENT_STATUS_OPERATION_FAILED {
            isScanningSubject.send(false)
            connectionStateSubject.send(.error("O leitor interrompeu a operação RFID"))
        }
    }

    // Proximity notification (locate mode)
    func srfidEventProximityNotify(_ readerID: Int32, aProximityPercent proximityPercent: Int32) {
        // Not used in inventory flow. Reserved for future "find tag" feature.
    }

    // Trigger event (gun trigger on sled readers)
    func srfidEventTriggerNotify(_ readerID: Int32, aTriggerEvent triggerEvent: SRFID_TRIGGEREVENT) {
        // Map trigger press to start/stop inventory for hands-free operation.
        switch triggerEvent {
        case SRFID_TRIGGEREVENT_PRESSED:
            if !isScanning { startInventory() }
        case SRFID_TRIGGEREVENT_RELEASED:
            if isScanning { stopInventory() }
        default:
            break
        }
    }

    func srfidEventMultiProximityNotify(_ readerID: Int32, aTagData tagData: srfidTagData!) {
        // Multi-tag location is outside the inventory workflow.
    }

    func srfidEventBatteryNotity(_ readerID: Int32, aBatteryEvent batteryEvent: srfidBatteryEvent!) {
        guard let batteryEvent else { return }

        let batteryLevel = Int(batteryEvent.getPowerLevel())
        var readers = discoveredReadersSubject.value
        guard let index = readers.firstIndex(where: { $0.id == String(readerID) }) else { return }

        let current = readers[index]
        let updated = RFIDReaderInfo(
            id: current.id,
            name: current.name,
            serialNumber: current.serialNumber,
            batteryLevel: batteryLevel
        )
        readers[index] = updated
        discoveredReadersSubject.send(readers)

        if connectedReaderId == readerID {
            connectionStateSubject.send(.connected(updated))
        }
    }

    func srfidEventWifiScan(_ readerID: Int32, wlanSCanObject wlanScanObject: srfidWlanScanList!) {
        // Wi-Fi provisioning is outside the inventory workflow.
    }
}

#endif
