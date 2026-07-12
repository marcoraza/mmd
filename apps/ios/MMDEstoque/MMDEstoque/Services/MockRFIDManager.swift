import Foundation
import Combine

/// Mock RFID implementation for development and testing without hardware.
///
/// Simulates realistic reader discovery, connection handshake, and
/// inventory scanning with staggered tag appearances. All timings are
/// chosen to feel plausible without slowing down dev workflows.
final class MockRFIDManager: RFIDReaderProtocol {

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

    // MARK: - Internal State

    private var scanWorkItem: DispatchWorkItem?
    private var tagSet = Set<String>()

    /// Fake readers that will "appear" during discovery.
    private let fakeReaders: [RFIDReaderInfo] = [
        RFIDReaderInfo(
            id: "mock-rfd40-001",
            name: "RFD40+ (Mock)",
            serialNumber: "23084501234567",
            batteryLevel: 85
        ),
        RFIDReaderInfo(
            id: "mock-rfd40-002",
            name: "RFD40+ Escritorio",
            serialNumber: "23084501234568",
            batteryLevel: 72
        ),
        RFIDReaderInfo(
            id: "mock-rfd8500-001",
            name: "RFD8500 (Mock)",
            serialNumber: "18023400987654",
            batteryLevel: 94
        ),
    ]

    /// Realistic EPC tag IDs that mimic SGTIN-96 encoded values.
    /// 24 hex characters each (96 bits).
    private let fakeTags: [String] = [
        "E28011702000020A5C41B6E0",
        "E28011702000020A5C41B7F1",
        "E28011702000020A5C41B802",
        "E28011702000020A5C41B913",
        "E28011702000020A5C41BA24",
        "E28011702000020A5C41BB35",
        "E28011702000020A5C41BC46",
        "E28011702000020A5C41BD57",
    ]

    // MARK: - RFIDReaderProtocol (actions)

    func discoverReaders() {
        // Reset state
        discoveredReadersSubject.send([])
        connectionStateSubject.send(.discovering)

        // Stagger reader appearances to mimic Bluetooth discovery
        for (index, reader) in fakeReaders.enumerated() {
            let delay = 0.5 + Double(index) * 0.6  // 0.5s, 1.1s, 1.7s
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                // Only add if still in discovering state
                guard case .discovering = self.connectionState else { return }

                var current = self.discoveredReadersSubject.value
                current.append(reader)
                self.discoveredReadersSubject.send(current)
            }
        }
    }

    func connect(to reader: RFIDReaderInfo) {
        connectionStateSubject.send(.connecting)

        // Simulate MFi handshake delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }

            // 10% chance of connection failure for realism
            if Int.random(in: 1...10) == 1 {
                self.connectionStateSubject.send(.error("Timeout ao conectar: tente novamente"))
                return
            }

            self.connectionStateSubject.send(.connected(reader))
        }
    }

    func disconnect() {
        if isScanning {
            stopInventory()
        }
        connectionStateSubject.send(.disconnected)
        discoveredReadersSubject.send([])
    }

    func startInventory() {
        guard connectionState.isConnected else { return }
        guard !isScanning else { return }

        isScanningSubject.send(true)

        // Pick a random subset of 5-8 tags
        let count = Int.random(in: 5...min(8, fakeTags.count))
        let selectedTags = Array(fakeTags.shuffled().prefix(count))

        // Emit tags one or two at a time over 2-3 seconds
        var delay: Double = 0.3
        var pending = selectedTags

        emitNextBatch(&pending, delay: delay)
    }

    func stopInventory() {
        scanWorkItem?.cancel()
        scanWorkItem = nil
        isScanningSubject.send(false)
    }

    func clearTags() {
        tagSet.removeAll()
        scannedTagsSubject.send([])
    }

    // MARK: - Tag Emission

    /// Recursively schedules tag emissions in small batches with
    /// randomized delays to simulate real-world read patterns.
    private func emitNextBatch(_ remaining: inout [String], delay: Double) {
        guard !remaining.isEmpty else { return }
        guard isScanning else { return }

        // Take 1-2 tags per batch
        let batchSize = min(remaining.count, Int.random(in: 1...2))
        let batch = Array(remaining.prefix(batchSize))
        remaining.removeFirst(batchSize)

        // Capture remaining for the closure
        let leftover = remaining

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isScanning else { return }

            for epc in batch {
                if self.tagSet.insert(epc).inserted {
                    self.scannedTagsSubject.send(Array(self.tagSet).sorted())
                }
            }

            // Schedule next batch with jittered delay
            if !leftover.isEmpty {
                var mutableLeftover = leftover
                let nextDelay = Double.random(in: 0.2...0.6)
                self.emitNextBatch(&mutableLeftover, delay: nextDelay)
            } else {
                // All tags emitted; keep scanning state until stopped.
                // In a real reader, new tags would keep appearing as
                // items enter the RF field.
            }
        }

        scanWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}
