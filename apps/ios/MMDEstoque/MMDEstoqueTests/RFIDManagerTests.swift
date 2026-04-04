import XCTest
import Combine
@testable import MMD_Estoque

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
    }

    func testInitialTagCountIsZero() {
        let manager = RFIDManager(useMock: true)
        XCTAssertEqual(manager.tagCount, 0)
    }

    // MARK: - Discovery

    func testDiscoverReadersTransitionsToDiscovering() {
        let mock = MockRFIDManager()
        let manager = RFIDManager(implementation: mock)

        let expectation = expectation(description: "State becomes discovering")

        manager.$connectionState
            .dropFirst()
            .first(where: { $0 == .discovering })
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        manager.discoverReaders()

        wait(for: [expectation], timeout: 2.0)
    }

    func testDiscoverReadersPopulatesReaderList() {
        let mock = MockRFIDManager()
        let manager = RFIDManager(implementation: mock)

        let expectation = expectation(description: "Readers discovered")

        manager.$discoveredReaders
            .dropFirst()
            .first(where: { !$0.isEmpty })
            .sink { readers in
                XCTAssertFalse(readers.isEmpty)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        manager.discoverReaders()

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Connection

    func testConnectTransitionsToConnecting() {
        let mock = MockRFIDManager()
        let manager = RFIDManager(implementation: mock)

        let reader = RFIDReaderInfo(
            id: "test-reader",
            name: "Test Reader",
            serialNumber: "12345",
            batteryLevel: 90
        )

        let expectation = expectation(description: "State becomes connecting")

        manager.$connectionState
            .dropFirst()
            .first(where: { $0 == .connecting })
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        manager.connect(to: reader)

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Scanning

    func testStartStopInventoryTogglesScanning() {
        let mock = MockRFIDManager()
        let manager = RFIDManager(implementation: mock)

        // First connect
        let reader = RFIDReaderInfo(
            id: "test-reader",
            name: "Test Reader",
            serialNumber: "12345",
            batteryLevel: 90
        )

        let connected = expectation(description: "Connected")

        manager.$connectionState
            .dropFirst()
            .first(where: { $0.isConnected })
            .sink { _ in connected.fulfill() }
            .store(in: &cancellables)

        manager.connect(to: reader)
        wait(for: [connected], timeout: 3.0)

        // Start scanning
        let scanning = expectation(description: "Scanning started")

        manager.$isScanning
            .dropFirst()
            .first(where: { $0 == true })
            .sink { _ in scanning.fulfill() }
            .store(in: &cancellables)

        manager.startInventory()
        wait(for: [scanning], timeout: 2.0)

        XCTAssertTrue(manager.isScanning)

        // Stop scanning
        manager.stopInventory()

        let stopped = expectation(description: "Scanning stopped")

        manager.$isScanning
            .dropFirst()
            .first(where: { $0 == false })
            .sink { _ in stopped.fulfill() }
            .store(in: &cancellables)

        wait(for: [stopped], timeout: 2.0)
        XCTAssertFalse(manager.isScanning)
    }

    // MARK: - Clear Tags

    func testClearTagsEmptiesScannedTags() {
        let mock = MockRFIDManager()
        let manager = RFIDManager(implementation: mock)

        // Directly verify clearTags on mock
        mock.clearTags()
        XCTAssertTrue(mock.scannedTags.isEmpty)
    }

    // MARK: - Status Text

    func testStatusTextDisconnected() {
        let manager = RFIDManager(useMock: true)
        XCTAssertEqual(manager.statusText, "Desconectado")
    }

    func testStatusIconDisconnected() {
        let manager = RFIDManager(useMock: true)
        XCTAssertEqual(manager.statusIcon, "antenna.radiowaves.left.and.right.slash")
    }

    // MARK: - Disconnect

    func testDisconnectResetsState() {
        let mock = MockRFIDManager()
        let manager = RFIDManager(implementation: mock)

        let reader = RFIDReaderInfo(
            id: "test-reader",
            name: "Test Reader",
            serialNumber: "12345",
            batteryLevel: 90
        )

        let connected = expectation(description: "Connected")

        manager.$connectionState
            .dropFirst()
            .first(where: { $0.isConnected })
            .sink { _ in connected.fulfill() }
            .store(in: &cancellables)

        manager.connect(to: reader)
        wait(for: [connected], timeout: 3.0)

        // Now disconnect
        let disconnected = expectation(description: "Disconnected")

        manager.$connectionState
            .dropFirst()
            .first(where: { $0 == .disconnected })
            .sink { _ in disconnected.fulfill() }
            .store(in: &cancellables)

        manager.disconnect()
        wait(for: [disconnected], timeout: 2.0)

        XCTAssertFalse(manager.isConnected)
    }
}
