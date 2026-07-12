import Foundation
import Combine
import os.log

// MARK: - ReturnResult

enum ReturnResult: Equatable {
    case pending
    case ok
    case problema(notas: String, desgaste: Int)
    case naoVoltou(notas: String?)
}

// MARK: - ReturnItemState

struct ReturnItemState: Identifiable {
    let id: UUID
    let resolved: ResolvedItem
    var result: ReturnResult = .pending

    var isScanned: Bool {
        switch result {
        case .pending: return false
        case .ok, .problema: return true
        case .naoVoltou: return false
        }
    }
}

// MARK: - ReturnConferenceSummary

struct ReturnConferenceSummary: Equatable {
    var ok: Int
    var problem: Int
    var notReturned: Int
    var pending: Int
    var total: Int

    var scanned: Int { ok + problem }
    var resolved: Int { ok + problem + notReturned }
    var canFinalize: Bool { total > 0 && pending == 0 }
}

extension Array where Element == ReturnItemState {
    var returnConferenceSummary: ReturnConferenceSummary {
        reduce(ReturnConferenceSummary(ok: 0, problem: 0, notReturned: 0, pending: 0, total: 0)) { partial, item in
            var next = partial
            switch item.result {
            case .pending:
                next.pending += 1
            case .ok:
                next.ok += 1
            case .problema:
                next.problem += 1
            case .naoVoltou:
                next.notReturned += 1
            }
            next.total += 1
            return next
        }
    }
}

// MARK: - ReturnViewModel

/// Manages the return flow: scanning returned equipment, marking defects,
/// and registering the return via API.
@MainActor
final class ReturnViewModel: ObservableObject {

    // MARK: - Published State

    @Published var outboundItems: [ReturnItemState] = []
    @Published var scanMethod: MetodoScan = .rfid
    @Published var isLoading = false
    @Published var isProcessingReturn = false
    @Published var returnComplete = false
    @Published var error: String?

    /// Serial ID of item pending condition assessment (shown in modal).
    @Published var pendingAssessmentId: UUID?

    // MARK: - Computed

    private var conferenceSummary: ReturnConferenceSummary {
        outboundItems.returnConferenceSummary
    }

    var okCount: Int {
        conferenceSummary.ok
    }

    var problemCount: Int {
        conferenceSummary.problem
    }

    var defectCount: Int {
        problemCount
    }

    var notReturnedCount: Int {
        conferenceSummary.notReturned
    }

    var missingCount: Int {
        notReturnedCount
    }

    var pendingCount: Int {
        conferenceSummary.pending
    }

    var totalItems: Int { conferenceSummary.total }

    var scannedCount: Int { conferenceSummary.scanned }

    var resolvedCount: Int { conferenceSummary.resolved }

    var canFinalize: Bool {
        conferenceSummary.canFinalize
    }

    var operationModeLabel: String {
        AppConfig.shared.isWebApiConfigured ? "API REAL" : "MODO MOCK"
    }

    var operationModeColor: String {
        AppConfig.shared.isWebApiConfigured ? "success" : "warning"
    }

    // MARK: - Dependencies

    let project: Project
    private let apiClient: APIClient
    private let rfidManager: RFIDManager
    private let logger = Logger(subsystem: "com.mmd.estoque", category: "Return")

    private var cancellables = Set<AnyCancellable>()
    private var processedTags = Set<String>()
    private var serialIdToIndex: [UUID: Int] = [:]

    // MARK: - Init

    init(project: Project, apiClient: APIClient, rfidManager: RFIDManager) {
        self.project = project
        self.apiClient = apiClient
        self.rfidManager = rfidManager
        subscribeToTags()
    }

    // MARK: - Load Outbound Items

    func loadOutboundItems() async {
        isLoading = true
        error = nil

        do {
            // Fetch SAIDA movements for this project
            let movements = try await apiClient.fetchProjectMovements(
                projectId: project.id,
                tipo: .saida
            )

            let serialIds = movements.map { $0.serialNumberId }
            guard !serialIds.isEmpty else {
                isLoading = false
                return
            }

            // Batch fetch serial numbers with equipment data
            let serials = try await apiClient.fetchSerialsByIds(serialIds)
            var items: [ReturnItemState] = []

            for serial in serials {
                guard let equipment = serial.item else { continue }
                let resolved = ResolvedItem(serialNumber: serial, equipment: equipment)
                let state = ReturnItemState(id: serial.id, resolved: resolved)
                items.append(state)
            }

            outboundItems = items
            rebuildSerialIndex()

            logger.info("Loaded \(items.count) outbound items for return")
        } catch {
            self.error = error.localizedDescription
            logger.error("Failed to load outbound items: \(error)")
        }

        isLoading = false
    }

    // MARK: - Tag Subscription

    private func subscribeToTags() {
        rfidManager.$scannedTags
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tags in
                self?.processNewTags(tags)
            }
            .store(in: &cancellables)
    }

    private func processNewTags(_ allTags: [String]) {
        let newTags = allTags.filter { !processedTags.contains($0) }
        guard !newTags.isEmpty else { return }

        processedTags.formUnion(newTags)

        Task {
            await resolveAndMatch(tags: newTags)
        }
    }

    // MARK: - QR Code Processing

    func processQRCode(_ code: String) {
        Task {
            do {
                guard let serial = try await apiClient.resolveQRCode(code) else { return }
                matchSerial(serial)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Resolve and Match

    private func resolveAndMatch(tags: [String]) async {
        do {
            let result = try await apiClient.recordAndResolveRfidTags(
                tags: tags,
                contexto: .retorno,
                projectId: project.id,
                reader: currentReaderRequest()
            )
            for item in result.resolved {
                matchSerial(item.serialNumber)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func currentReaderRequest() -> RfidScanReaderRequest? {
        guard let reader = rfidManager.connectedReader else { return nil }
        return RfidScanReaderRequest(
            nome: reader.name,
            modelo: "Zebra RFD40",
            serialFabrica: reader.serialNumber,
            bateria: reader.batteryLevel
        )
    }

    private func matchSerial(_ serial: SerialNumber) {
        guard let index = serialIdToIndex[serial.id] else { return }
        guard case .pending = outboundItems[index].result else { return }

        // Show assessment modal
        pendingAssessmentId = serial.id
    }

    // MARK: - Condition Assessment

    func markAsOK(serialId: UUID) {
        guard let index = serialIdToIndex[serialId] else { return }
        outboundItems[index].result = .ok
        pendingAssessmentId = nil
    }

    func markAsProblem(serialId: UUID, notas: String, desgaste: Int) {
        guard let index = serialIdToIndex[serialId] else { return }
        outboundItems[index].result = .problema(notas: notas.trimmingCharacters(in: .whitespacesAndNewlines), desgaste: desgaste)
        pendingAssessmentId = nil
    }

    func markAsNotReturned(serialId: UUID, notas: String?) {
        guard let index = serialIdToIndex[serialId] else { return }
        outboundItems[index].result = .naoVoltou(notas: normalizeNote(notas))
        pendingAssessmentId = nil
    }

    // MARK: - Finalize Return

    func finalizeReturn() async {
        isProcessingReturn = true
        error = nil
        defer { isProcessingReturn = false }

        guard canFinalize else {
            error = pendingCount > 0
                ? "Ainda existem unidades sem conferência."
                : "Nada para receber de volta."
            return
        }

        do {
            let items = buildReturnProjectItems()
            if AppConfig.shared.isWebApiConfigured {
                _ = try await apiClient.returnProject(
                    projectId: project.id,
                    metodoScan: scanMethod,
                    items: items
                )
            } else {
                logger.notice("Return finalized in mock mode with \(items.count) items")
            }

            returnComplete = true
            logger.info("Return finalized: \(self.okCount) OK, \(self.problemCount) problema, \(self.notReturnedCount) nao voltou")
        } catch {
            self.error = error.localizedDescription
            logger.error("Return failed: \(error)")
        }
    }

    // MARK: - Reset

    func reset() {
        outboundItems.removeAll()
        serialIdToIndex.removeAll()
        processedTags.removeAll()
        pendingAssessmentId = nil
        returnComplete = false
        error = nil
        rfidManager.clearTags()
    }

    func openAssessment(serialId: UUID) {
        guard serialIdToIndex[serialId] != nil else { return }
        pendingAssessmentId = serialId
    }

    func buildReturnProjectItems() -> [ReturnProjectItemRequest] {
        outboundItems.compactMap { item in
            switch item.result {
            case .pending:
                return nil
            case .ok:
                return ReturnProjectItemRequest(
                    serialId: item.id,
                    desgaste: item.resolved.serialNumber.desgaste,
                    resultado: .ok,
                    observacao: nil
                )
            case .problema(let notas, let desgaste):
                return ReturnProjectItemRequest(
                    serialId: item.id,
                    desgaste: desgaste,
                    resultado: .problema,
                    observacao: normalizeNote(notas)
                )
            case .naoVoltou(let notas):
                return ReturnProjectItemRequest(
                    serialId: item.id,
                    desgaste: item.resolved.serialNumber.desgaste,
                    resultado: .naoVoltou,
                    observacao: normalizeNote(notas)
                )
            }
        }
    }

    private func rebuildSerialIndex() {
        serialIdToIndex.removeAll()
        for (index, item) in outboundItems.enumerated() {
            serialIdToIndex[item.id] = index
        }
    }

    private func normalizeNote(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
