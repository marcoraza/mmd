import XCTest
import Combine
@testable import EventPro

@MainActor
final class RFIDManagerTests: XCTestCase {

    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Init

    func testInitWithMockCreatesMockImplementation() {
        let manager = RFIDManager(useMock: true)
        XCTAssertEqual(manager.connectionState, .disconnected)
        XCTAssertFalse(manager.isConnected)
        XCTAssertTrue(manager.discoveredReaders.isEmpty)
        XCTAssertTrue(manager.scannedTags.isEmpty)
        XCTAssertFalse(manager.isScanning)
        XCTAssertNil(manager.lastError)
        XCTAssertEqual(manager.runtimeMode, .mock)
    }

    func testInitialTagCountIsZero() {
        XCTAssertEqual(RFIDManager(useMock: true).tagCount, 0)
    }

    // MARK: - Descoberta

    func testDiscoverReadersTransitionsToDiscovering() async {
        let manager = RFIDManager(implementation: MockRFIDManager())
        let expectation = expectation(description: "Estado vira discovering")

        manager.$connectionState
            .dropFirst()
            .first { $0 == .discovering }
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        manager.discoverReaders()
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testDiscoverReadersPopulatesReaderList() async {
        let manager = RFIDManager(implementation: MockRFIDManager())
        let expectation = expectation(description: "Leitores descobertos")

        manager.$discoveredReaders
            .dropFirst()
            .first { !$0.isEmpty }
            .sink { readers in
                XCTAssertFalse(readers.isEmpty)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        manager.discoverReaders()
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    // MARK: - Conexão

    func testConnectTransitionsToConnecting() async {
        let manager = RFIDManager(implementation: MockRFIDManager())
        let expectation = expectation(description: "Estado vira connecting")

        manager.$connectionState
            .dropFirst()
            .first { $0 == .connecting }
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        manager.connect(to: Self.testReader)
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testConnectPublishesBatteryFromReader() async {
        let manager = RFIDManager(implementation: MockRFIDManager())
        let comBateria = expectation(description: "Bateria publicada")

        manager.$batteryLevel
            .first { $0 == 90 }
            .sink { _ in comBateria.fulfill() }
            .store(in: &cancellables)

        manager.connect(to: Self.testReader)
        await fulfillment(of: [comBateria], timeout: 4.0)

        XCTAssertTrue(manager.isConnected)
        XCTAssertEqual(manager.connectedReader?.batteryLevel, 90)
    }

    func testDisconnectResetsState() async {
        let manager = RFIDManager(implementation: MockRFIDManager())

        let connected = expectation(description: "Conectado")
        manager.$connectionState
            .dropFirst()
            .first { $0.isConnected }
            .sink { _ in connected.fulfill() }
            .store(in: &cancellables)

        manager.connect(to: Self.testReader)
        await fulfillment(of: [connected], timeout: 4.0)

        let disconnected = expectation(description: "Desconectado")
        manager.$connectionState
            .dropFirst()
            .first { $0 == .disconnected }
            .sink { _ in disconnected.fulfill() }
            .store(in: &cancellables)

        manager.disconnect()
        await fulfillment(of: [disconnected], timeout: 2.0)

        XCTAssertFalse(manager.isConnected)
        XCTAssertNil(manager.connectedReader)
    }

    // MARK: - Inventário

    func testStartStopInventoryTogglesScanning() async {
        let manager = RFIDManager(implementation: MockRFIDManager())

        let connected = expectation(description: "Conectado")
        manager.$connectionState
            .dropFirst()
            .first { $0.isConnected }
            .sink { _ in connected.fulfill() }
            .store(in: &cancellables)

        manager.connect(to: Self.testReader)
        await fulfillment(of: [connected], timeout: 4.0)

        let scanning = expectation(description: "Leitura iniciada")
        manager.$isScanning
            .dropFirst()
            .first { $0 }
            .sink { _ in scanning.fulfill() }
            .store(in: &cancellables)

        manager.startInventory()
        await fulfillment(of: [scanning], timeout: 2.0)
        XCTAssertTrue(manager.isScanning)

        let stopped = expectation(description: "Leitura parada")
        manager.$isScanning
            .dropFirst()
            .first { !$0 }
            .sink { _ in stopped.fulfill() }
            .store(in: &cancellables)

        manager.stopInventory()
        await fulfillment(of: [stopped], timeout: 2.0)
        XCTAssertFalse(manager.isScanning)
    }

    func testStartInventorySemConexaoPublicaErroTipado() {
        let mock = MockRFIDManager()
        mock.startInventory()
        XCTAssertEqual(mock.lastError, .notConnected)
        XCTAssertFalse(mock.isScanning)
    }

    // MARK: - Ordem de leitura (bug do legado)

    func testTagReadsPreservamOrdemDeLeitura() {
        // O legado publicava `Array(tagSet).sorted()`: a ordem alfabética
        // apagava a ordem de chegada e `.last` apontava para outra tag.
        let stub = StubRFIDReader(
            connectionState: .disconnected,
            discoveredReaders: [],
            tagReads: [
                RFIDTagRead(tag: "ZZZZ0001", rssi: -50),
                RFIDTagRead(tag: "AAAA0002", rssi: -41),
                RFIDTagRead(tag: "MMMM0003", rssi: nil),
            ],
            isScanning: false
        )
        let manager = RFIDManager(implementation: stub)

        XCTAssertEqual(manager.scannedTags, ["ZZZZ0001", "AAAA0002", "MMMM0003"])
        XCTAssertEqual(manager.lastReadTag, "MMMM0003")
        XCTAssertNotEqual(manager.lastReadTag, manager.scannedTags.sorted().last)
    }

    func testRssiByTagIgnoraLeiturasSemRssi() {
        let stub = StubRFIDReader(
            connectionState: .disconnected,
            discoveredReaders: [],
            tagReads: [
                RFIDTagRead(tag: "AAAA0001", rssi: -55),
                RFIDTagRead(tag: "BBBB0002", rssi: nil),
            ],
            isScanning: false
        )
        let manager = RFIDManager(implementation: stub)

        XCTAssertEqual(manager.rssiByTag, ["AAAA0001": -55])
    }

    func testMergingPeakMantemOMelhorRssi() {
        let leitura = RFIDTagRead(tag: "AAAA0001", rssi: -70)
        XCTAssertEqual(leitura.mergingPeak(rssi: -40).rssi, -40, "RSSI menos negativo é mais forte")
        XCTAssertEqual(leitura.mergingPeak(rssi: -90).rssi, -70)
        XCTAssertEqual(leitura.mergingPeak(rssi: nil).rssi, -70)
        XCTAssertEqual(
            RFIDTagRead(tag: "A", rssi: nil).mergingPeak(rssi: -30).rssi,
            -30
        )
    }

    // MARK: - Potência

    func testSetAntennaPowerPersisteEhLimitada() {
        let mock = MockRFIDManager()
        let manager = RFIDManager(implementation: mock)

        manager.setAntennaPower(deciDbm: 9999)
        XCTAssertEqual(AppConfig.shared.antennaPowerDeciDbm, AppConfig.maxAntennaPowerDeciDbm)
        XCTAssertEqual(mock.antennaPowerDeciDbm, AppConfig.maxAntennaPowerDeciDbm)

        manager.setAntennaPower(deciDbm: 0)
        XCTAssertEqual(AppConfig.shared.antennaPowerDeciDbm, AppConfig.minAntennaPowerDeciDbm)
        XCTAssertEqual(mock.antennaPowerDeciDbm, AppConfig.minAntennaPowerDeciDbm)

        manager.setAntennaPower(deciDbm: AppConfig.defaultAntennaPowerDeciDbm)
    }

    // MARK: - Troca de implementação

    func testConfigureSwapsImplementationAndResetsPublishedState() {
        let connectedReader = Self.testReader

        let mockImplementation = StubRFIDReader(
            connectionState: .connected(connectedReader),
            discoveredReaders: [connectedReader],
            tagReads: [RFIDTagRead(tag: "E28011702000020A5C41B6E0", rssi: -44)],
            isScanning: true
        )

        let zebraImplementation = StubRFIDReader(
            connectionState: .disconnected,
            discoveredReaders: [],
            tagReads: [],
            isScanning: false
        )

        let manager = RFIDManager(
            useMock: true,
            implementationFactory: { useMock in
                useMock ? (mockImplementation, .mock) : (zebraImplementation, .zebra)
            }
        )

        XCTAssertEqual(manager.runtimeMode, .mock)
        XCTAssertEqual(manager.tagCount, 1)
        XCTAssertTrue(manager.isScanning)

        manager.configure(useMock: false)

        XCTAssertEqual(manager.runtimeMode, .zebra)
        XCTAssertEqual(manager.connectionState, .disconnected)
        XCTAssertTrue(manager.discoveredReaders.isEmpty)
        XCTAssertTrue(manager.scannedTags.isEmpty)
        XCTAssertFalse(manager.isScanning)
        XCTAssertTrue(mockImplementation.disconnectCalled)
        XCTAssertTrue(mockImplementation.clearTagsCalled)
        XCTAssertTrue(mockImplementation.stopInventoryCalled)
    }

    // MARK: - Texto de status

    func testStatusTextDisconnected() {
        XCTAssertEqual(RFIDManager(useMock: true).statusText, "Desconectado")
    }

    func testStatusIconDisconnected() {
        XCTAssertEqual(
            RFIDManager(useMock: true).statusIcon,
            "antenna.radiowaves.left.and.right.slash"
        )
    }

    func testReaderRequestSemConexaoEhNil() {
        XCTAssertNil(RFIDManager(useMock: true).readerRequest())
    }

    // MARK: - Erros tipados

    func testErrosSaoSeparadosDoEstadoDeConexao() {
        // O estado de conexão não tem caso de erro: quem carrega falha é
        // `lastError`, tipado.
        let estados: [RFIDConnectionState] = [
            .disconnected, .discovering, .connecting, .connected(Self.testReader),
        ]
        XCTAssertEqual(estados.filter(\.isConnected).count, 1)
        XCTAssertEqual(estados.filter(\.isBusy).count, 2)

        XCTAssertNotNil(RFIDReaderError.sdkUnavailable.errorDescription)
        XCTAssertFalse(RFIDReaderError.sdkUnavailable.isRecoverable)
        XCTAssertTrue(RFIDReaderError.notConnected.isRecoverable)
        XCTAssertEqual(
            RFIDReaderError.connectionFailed(sdkCode: "SRFID_RESULT_FAILURE", message: nil),
            RFIDReaderError.connectionFailed(sdkCode: "SRFID_RESULT_FAILURE", message: nil)
        )
    }

    // MARK: - Helpers

    private static let testReader = RFIDReaderInfo(
        id: "test-reader",
        name: "Test Reader",
        serialNumber: "12345",
        batteryLevel: 90
    )
}

// MARK: - Stub

final class StubRFIDReader: RFIDReaderProtocol {

    private let connectionStateSubject: CurrentValueSubject<RFIDConnectionState, Never>
    private let discoveredReadersSubject: CurrentValueSubject<[RFIDReaderInfo], Never>
    private let tagReadsSubject: CurrentValueSubject<[RFIDTagRead], Never>
    private let isScanningSubject: CurrentValueSubject<Bool, Never>
    private let batteryLevelSubject: CurrentValueSubject<Int?, Never>
    private let lastErrorSubject = CurrentValueSubject<RFIDReaderError?, Never>(nil)

    private(set) var disconnectCalled = false
    private(set) var clearTagsCalled = false
    private(set) var stopInventoryCalled = false
    private(set) var lastAntennaPowerDeciDbm: Int?

    init(
        connectionState: RFIDConnectionState,
        discoveredReaders: [RFIDReaderInfo],
        tagReads: [RFIDTagRead],
        isScanning: Bool,
        batteryLevel: Int? = nil
    ) {
        self.connectionStateSubject = CurrentValueSubject(connectionState)
        self.discoveredReadersSubject = CurrentValueSubject(discoveredReaders)
        self.tagReadsSubject = CurrentValueSubject(tagReads)
        self.isScanningSubject = CurrentValueSubject(isScanning)
        self.batteryLevelSubject = CurrentValueSubject(batteryLevel)
    }

    var connectionState: RFIDConnectionState { connectionStateSubject.value }
    var connectionStatePublisher: AnyPublisher<RFIDConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    var discoveredReaders: [RFIDReaderInfo] { discoveredReadersSubject.value }
    var discoveredReadersPublisher: AnyPublisher<[RFIDReaderInfo], Never> {
        discoveredReadersSubject.eraseToAnyPublisher()
    }

    var tagReads: [RFIDTagRead] { tagReadsSubject.value }
    var tagReadsPublisher: AnyPublisher<[RFIDTagRead], Never> {
        tagReadsSubject.eraseToAnyPublisher()
    }

    var isScanning: Bool { isScanningSubject.value }
    var isScanningPublisher: AnyPublisher<Bool, Never> {
        isScanningSubject.eraseToAnyPublisher()
    }

    var batteryLevel: Int? { batteryLevelSubject.value }
    var batteryLevelPublisher: AnyPublisher<Int?, Never> {
        batteryLevelSubject.eraseToAnyPublisher()
    }

    var lastError: RFIDReaderError? { lastErrorSubject.value }
    var lastErrorPublisher: AnyPublisher<RFIDReaderError?, Never> {
        lastErrorSubject.eraseToAnyPublisher()
    }

    func discoverReaders() {}
    func connect(to reader: RFIDReaderInfo) {}

    func disconnect() {
        disconnectCalled = true
        connectionStateSubject.send(.disconnected)
        discoveredReadersSubject.send([])
        isScanningSubject.send(false)
        batteryLevelSubject.send(nil)
    }

    func startInventory() {}

    func stopInventory() {
        stopInventoryCalled = true
        isScanningSubject.send(false)
    }

    func clearTags() {
        clearTagsCalled = true
        tagReadsSubject.send([])
    }

    func setAntennaPower(deciDbm: Int) {
        lastAntennaPowerDeciDbm = deciDbm
    }

    func refreshBattery() {}

    func clearError() {
        lastErrorSubject.send(nil)
    }
}
