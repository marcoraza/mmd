import Foundation
import Combine

/// Leitor RFID simulado, para desenvolver sem hardware.
///
/// Simula descoberta, handshake, inventário com tags chegando aos poucos,
/// bateria e RSSI. As tags saem já normalizadas e **na ordem de leitura**.
///
/// Diferente do legado, a falha de conexão não é aleatória por padrão
/// (`simulatedFailureRate = 0`): teste que depende de conectar não pode falhar
/// 1 vez em 10. Quem quiser exercitar o caminho de erro passa uma taxa.
final class MockRFIDManager: RFIDReaderProtocol {

    // MARK: - Combine Subjects

    private let connectionStateSubject = CurrentValueSubject<RFIDConnectionState, Never>(.disconnected)
    private let discoveredReadersSubject = CurrentValueSubject<[RFIDReaderInfo], Never>([])
    private let tagReadsSubject = CurrentValueSubject<[RFIDTagRead], Never>([])
    private let isScanningSubject = CurrentValueSubject<Bool, Never>(false)
    private let batteryLevelSubject = CurrentValueSubject<Int?, Never>(nil)
    private let lastErrorSubject = CurrentValueSubject<RFIDReaderError?, Never>(nil)

    // MARK: - RFIDReaderProtocol (estado)

    var connectionState: RFIDConnectionState { connectionStateSubject.value }
    var connectionStatePublisher: AnyPublisher<RFIDConnectionState, Never> {
        connectionStateSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    var discoveredReaders: [RFIDReaderInfo] { discoveredReadersSubject.value }
    var discoveredReadersPublisher: AnyPublisher<[RFIDReaderInfo], Never> {
        discoveredReadersSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    var tagReads: [RFIDTagRead] { tagReadsSubject.value }
    var tagReadsPublisher: AnyPublisher<[RFIDTagRead], Never> {
        tagReadsSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    var isScanning: Bool { isScanningSubject.value }
    var isScanningPublisher: AnyPublisher<Bool, Never> {
        isScanningSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    var batteryLevel: Int? { batteryLevelSubject.value }
    var batteryLevelPublisher: AnyPublisher<Int?, Never> {
        batteryLevelSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    var lastError: RFIDReaderError? { lastErrorSubject.value }
    var lastErrorPublisher: AnyPublisher<RFIDReaderError?, Never> {
        lastErrorSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    // MARK: - Configuração

    /// Probabilidade de falha no handshake, 0.0 a 1.0. Zero por padrão.
    private let simulatedFailureRate: Double

    /// Potência atual, em décimos de dBm. Influencia o RSSI simulado e quantas
    /// tags aparecem: potência baixa lê menos e mais perto, igual ao real.
    private(set) var antennaPowerDeciDbm: Int = AppConfig.defaultAntennaPowerDeciDbm

    // MARK: - Estado interno

    private var scanWorkItem: DispatchWorkItem?
    private var seenTags = Set<String>()

    /// Leitores falsos que "aparecem" na descoberta.
    private let fakeReaders: [RFIDReaderInfo] = [
        RFIDReaderInfo(id: "mock-rfd40-001", name: "RFD40+ (Simulado)", serialNumber: "23084501234567", batteryLevel: 85),
        RFIDReaderInfo(id: "mock-rfd40-002", name: "RFD40+ Escritorio", serialNumber: "23084501234568", batteryLevel: 72),
        RFIDReaderInfo(id: "mock-rfd8500-001", name: "RFD8500 (Simulado)", serialNumber: "18023400987654", batteryLevel: 94),
    ]

    /// EPCs no formato SGTIN-96 (24 caracteres hex), já normalizados.
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

    // MARK: - Init

    init(simulatedFailureRate: Double = 0) {
        self.simulatedFailureRate = min(1, max(0, simulatedFailureRate))
    }

    deinit {
        scanWorkItem?.cancel()
    }

    // MARK: - RFIDReaderProtocol (ações)

    func discoverReaders() {
        lastErrorSubject.send(nil)
        discoveredReadersSubject.send([])
        connectionStateSubject.send(.discovering)

        for (index, reader) in fakeReaders.enumerated() {
            let delay = 0.5 + Double(index) * 0.6
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                guard case .discovering = self.connectionState else { return }
                var current = self.discoveredReadersSubject.value
                current.append(reader)
                self.discoveredReadersSubject.send(current)
            }
        }
    }

    func connect(to reader: RFIDReaderInfo) {
        lastErrorSubject.send(nil)
        connectionStateSubject.send(.connecting)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }

            if self.simulatedFailureRate > 0, Double.random(in: 0..<1) < self.simulatedFailureRate {
                self.lastErrorSubject.send(
                    .connectionFailed(sdkCode: "SRFID_RESULT_RESPONSE_TIMEOUT", message: "Timeout simulado")
                )
                self.connectionStateSubject.send(.disconnected)
                return
            }

            self.connectionStateSubject.send(.connected(reader))
            self.batteryLevelSubject.send(reader.batteryLevel)
        }
    }

    func disconnect() {
        if isScanning {
            stopInventory()
        }
        connectionStateSubject.send(.disconnected)
        discoveredReadersSubject.send([])
        batteryLevelSubject.send(nil)
    }

    func startInventory() {
        guard connectionState.isConnected else {
            lastErrorSubject.send(.notConnected)
            return
        }
        guard !isScanning else { return }

        lastErrorSubject.send(nil)
        isScanningSubject.send(true)

        // Potência alta enxerga mais tags; potência baixa, só as próximas.
        let reach = Double(antennaPowerDeciDbm - AppConfig.minAntennaPowerDeciDbm)
            / Double(AppConfig.maxAntennaPowerDeciDbm - AppConfig.minAntennaPowerDeciDbm)
        let maxCount = max(1, Int((Double(fakeTags.count) * max(0.25, reach)).rounded()))
        let count = Int.random(in: 1...maxCount)
        let selected = Array(fakeTags.shuffled().prefix(count))

        emitNextBatch(selected, delay: 0.3)
    }

    func stopInventory() {
        scanWorkItem?.cancel()
        scanWorkItem = nil
        isScanningSubject.send(false)
    }

    func clearTags() {
        seenTags.removeAll()
        tagReadsSubject.send([])
    }

    func setAntennaPower(deciDbm: Int) {
        guard deciDbm >= AppConfig.minAntennaPowerDeciDbm,
              deciDbm <= AppConfig.maxAntennaPowerDeciDbm else {
            lastErrorSubject.send(
                .invalidConfiguration(
                    "Potência \(deciDbm) fora da faixa simulada (\(AppConfig.minAntennaPowerDeciDbm)–\(AppConfig.maxAntennaPowerDeciDbm))."
                )
            )
            return
        }
        antennaPowerDeciDbm = deciDbm
    }

    func refreshBattery() {
        guard let reader = connectionState.readerInfo else {
            lastErrorSubject.send(.notConnected)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.connectionState.isConnected else { return }
            let base = reader.batteryLevel ?? 80
            self.batteryLevelSubject.send(max(0, min(100, base + Int.random(in: -2...0))))
        }
    }

    func clearError() {
        lastErrorSubject.send(nil)
    }

    // MARK: - Emissão de tags

    /// Emite as tags em lotes pequenos com atraso variável, imitando o padrão
    /// de leitura real. Cada tag entra **no fim da lista**, preservando a ordem.
    private func emitNextBatch(_ remaining: [String], delay: Double) {
        guard !remaining.isEmpty, isScanning else { return }

        let batchSize = min(remaining.count, Int.random(in: 1...2))
        let batch = Array(remaining.prefix(batchSize))
        let leftover = Array(remaining.dropFirst(batchSize))

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isScanning else { return }

            var reads = self.tagReadsSubject.value
            var changed = false

            for epc in batch where self.seenTags.insert(epc).inserted {
                reads.append(RFIDTagRead(tag: epc, rssi: self.simulatedRssi()))
                changed = true
            }

            if changed {
                self.tagReadsSubject.send(reads)
            }

            if !leftover.isEmpty {
                self.emitNextBatch(leftover, delay: Double.random(in: 0.2...0.6))
            }
        }

        scanWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    /// RSSI plausível: potência maior deixa a leitura mais forte (menos negativa).
    private func simulatedRssi() -> Int {
        let span = Double(AppConfig.maxAntennaPowerDeciDbm - AppConfig.minAntennaPowerDeciDbm)
        let normalized = Double(antennaPowerDeciDbm - AppConfig.minAntennaPowerDeciDbm) / span
        let base = -75.0 + normalized * 35.0
        return Int((base + Double.random(in: -6...6)).rounded())
    }
}
