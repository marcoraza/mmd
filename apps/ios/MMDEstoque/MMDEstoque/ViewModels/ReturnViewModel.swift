import Foundation
import Combine
import os.log

// MARK: - ReturnResult

enum ReturnResult {
    case pending
    case ok
    case defeito(notas: String, desgaste: Int)
}

// MARK: - ReturnItemState

struct ReturnItemState: Identifiable {
    let id: UUID
    let resolved: ResolvedItem
    var result: ReturnResult = .pending

    var isScanned: Bool {
        switch result {
        case .pending: return false
        case .ok, .defeito: return true
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

    var okCount: Int {
        outboundItems.filter {
            if case .ok = $0.result { return true }
            return false
        }.count
    }

    var defectCount: Int {
        outboundItems.filter {
            if case .defeito = $0.result { return true }
            return false
        }.count
    }

    var missingCount: Int {
        outboundItems.filter {
            if case .pending = $0.result { return true }
            return false
        }.count
    }

    var totalItems: Int { outboundItems.count }

    var scannedCount: Int { okCount + defectCount }

    var canFinalize: Bool {
        !outboundItems.isEmpty && scannedCount > 0
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

            // Build index for fast lookup
            for (index, item) in outboundItems.enumerated() {
                serialIdToIndex[item.id] = index
            }

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
            let result = try await apiClient.resolveRfidTags(tags)
            for item in result.resolved {
                matchSerial(item.serialNumber)
            }
        } catch {
            self.error = error.localizedDescription
        }
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

    func markAsDefect(serialId: UUID, notas: String, desgaste: Int) {
        guard let index = serialIdToIndex[serialId] else { return }
        outboundItems[index].result = .defeito(notas: notas, desgaste: desgaste)
        pendingAssessmentId = nil
    }

    // MARK: - Finalize Return

    func finalizeReturn() async {
        isProcessingReturn = true
        error = nil

        do {
            var returns: [(serialId: UUID, tipo: TipoMovimentacao, statusNovo: String, desgaste: Int?, metodoScan: MetodoScan, notas: String?)] = []

            for item in outboundItems {
                switch item.result {
                case .ok:
                    returns.append((
                        serialId: item.id,
                        tipo: .retorno,
                        statusNovo: StatusSerial.disponivel.rawValue,
                        desgaste: nil,
                        metodoScan: scanMethod,
                        notas: nil
                    ))
                case .defeito(let notas, let desgaste):
                    returns.append((
                        serialId: item.id,
                        tipo: .dano,
                        statusNovo: StatusSerial.manutencao.rawValue,
                        desgaste: desgaste,
                        metodoScan: scanMethod,
                        notas: notas
                    ))
                case .pending:
                    // Not returned, stays EM_CAMPO
                    break
                }
            }

            if !returns.isEmpty {
                try await apiClient.registerReturn(projectId: project.id, returns: returns)
            }

            // If all items returned, mark project as finalizado
            if missingCount == 0 {
                try await apiClient.updateProjectStatus(projectId: project.id, status: .finalizado)
            }

            returnComplete = true
            logger.info("Return finalized: \(self.okCount) OK, \(self.defectCount) defeito, \(self.missingCount) faltando")
        } catch {
            self.error = error.localizedDescription
            logger.error("Return failed: \(error)")
        }

        isProcessingReturn = false
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
}
