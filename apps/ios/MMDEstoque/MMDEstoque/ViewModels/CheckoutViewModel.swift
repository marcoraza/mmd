import Foundation
import Combine
import os.log

// MARK: - PackingItemValidation

enum PackingItemValidation {
    case pending
    case complete
    case over
}

// MARK: - CheckoutViewModel

/// Manages the checkout flow: scanning equipment against a packing list,
/// validating matches in real-time, and registering the checkout via API.
@MainActor
final class CheckoutViewModel: ObservableObject {

    // MARK: - Published State

    @Published var packingListItems: [PackingListItem] = []
    @Published var eventSummary: EventSummary?
    @Published var scannedSerials: [UUID: ResolvedItem] = [:]
    @Published var matchedCounts: [UUID: Int] = [:]
    @Published var extraItems: [ResolvedItem] = []
    @Published var unresolvedTags: [String] = []
    @Published var scanMethod: MetodoScan = .rfid
    @Published var isLoading = false
    @Published var isProcessingCheckout = false
    @Published var checkoutComplete = false
    @Published var error: String?
    @Published var summaryNotice: String?

    // MARK: - Computed

    var totalExpected: Int {
        packingListItems.reduce(0) { $0 + $1.quantidade }
    }

    var totalScanned: Int {
        matchedCounts.values.reduce(0, +)
    }

    var canFinalize: Bool {
        guard !packingListItems.isEmpty, extraItems.isEmpty else { return false }
        return packingListItems.allSatisfy { item in
            (matchedCounts[item.id] ?? 0) >= item.quantidade
        }
    }

    var missingCount: Int {
        packingListItems.reduce(0) { total, item in
            total + max(item.quantidade - (matchedCounts[item.id] ?? 0), 0)
        }
    }

    var operationModeLabel: String {
        AppConfig.shared.isWebApiConfigured ? "API REAL" : "MODO MOCK"
    }

    var operationModeColor: String {
        AppConfig.shared.isWebApiConfigured ? "ndSuccess" : "ndWarning"
    }

    var checkoutWarnings: [String] {
        var warnings: [String] = []

        if missingCount > 0 {
            warnings.append("\(missingCount) itens faltando no checklist.")
        }

        if !extraItems.isEmpty {
            warnings.append("\(extraItems.count) itens extras fora do packing.")
        }

        if !unresolvedTags.isEmpty {
            warnings.append("\(unresolvedTags.count) leituras nao resolvidas.")
        }

        if !AppConfig.shared.isWebApiConfigured {
            warnings.append("Checkout real desativado. Confirmacao roda em mock.")
        }

        return warnings
    }

    // MARK: - Dependencies

    let project: Project
    private let apiClient: APIClient
    private let rfidManager: RFIDManager
    private let logger = Logger(subsystem: "com.mmd.estoque", category: "Checkout")

    private var cancellables = Set<AnyCancellable>()
    private var processedTags = Set<String>()

    // MARK: - Init

    init(project: Project, apiClient: APIClient, rfidManager: RFIDManager) {
        self.project = project
        self.apiClient = apiClient
        self.rfidManager = rfidManager
        subscribeToTags()
    }

    // MARK: - Load Packing List

    func loadPackingList() async {
        isLoading = true
        error = nil
        summaryNotice = nil

        do {
            packingListItems = try await apiClient.fetchPackingList(projectId: project.id)
            logger.info("Loaded \(self.packingListItems.count) packing list items")
        } catch {
            self.error = error.localizedDescription
            logger.error("Failed to load packing list: \(error)")
        }

        do {
            eventSummary = try await apiClient.fetchEventSummary(projectId: project.id)
        } catch APIError.webApiNotConfigured {
            summaryNotice = "Resumo avancado indisponivel em modo mock."
        } catch {
            summaryNotice = "Resumo avancado indisponivel: \(error.localizedDescription)"
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
                guard let serial = try await apiClient.resolveQRCode(code) else {
                    unresolvedTags.append(code)
                    return
                }

                guard let equipment = serial.item else {
                    unresolvedTags.append(code)
                    return
                }

                let resolved = ResolvedItem(serialNumber: serial, equipment: equipment)
                matchResolvedItem(resolved)
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
                contexto: .checkOutEvento,
                projectId: project.id,
                reader: currentReaderRequest()
            )

            for item in result.resolved {
                matchResolvedItem(item)
            }

            unresolvedTags.append(contentsOf: result.unresolved)
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

    private func matchResolvedItem(_ resolved: ResolvedItem) {
        let serialId = resolved.serialNumber.id

        // Skip if already scanned
        guard scannedSerials[serialId] == nil else { return }
        scannedSerials[serialId] = resolved

        // Find matching packing list item by item type
        let matchingPackingItems = packingListItems.filter { $0.itemId == resolved.equipment.id }

        if let packingItem = matchingPackingItems.first {
            // Check designated serials if specified
            if let designated = packingItem.serialNumbersDesignados, !designated.isEmpty {
                if designated.contains(serialId) {
                    matchedCounts[packingItem.id, default: 0] += 1
                } else {
                    // Right type but wrong serial
                    extraItems.append(resolved)
                }
            } else {
                // No designated serials, match by type up to quantity
                matchedCounts[packingItem.id, default: 0] += 1
            }
        } else {
            // Not in packing list at all
            extraItems.append(resolved)
        }
    }

    // MARK: - Validation State

    func validationState(for packingItem: PackingListItem) -> PackingItemValidation {
        let matched = matchedCounts[packingItem.id] ?? 0
        if matched >= packingItem.quantidade {
            return matched > packingItem.quantidade ? .over : .complete
        }
        return .pending
    }

    func validationColor(for packingItem: PackingListItem) -> String {
        switch validationState(for: packingItem) {
        case .pending: return "ndWarning"
        case .complete: return "ndSuccess"
        case .over: return "ndAccent"
        }
    }

    // MARK: - Finalize Checkout

    func finalizeCheckout() async {
        isProcessingCheckout = true
        error = nil

        do {
            if AppConfig.shared.isWebApiConfigured {
                let result = try await apiClient.checkoutProject(
                    projectId: project.id,
                    metodoScan: scanMethod
                )
                logger.info("Checkout finalized through web API: \(result.count) items")
            } else {
                logger.info("Checkout mock finalized locally: \(self.scannedSerials.count) scanned items")
            }

            checkoutComplete = true
        } catch {
            self.error = error.localizedDescription
            logger.error("Checkout failed: \(error)")
        }

        isProcessingCheckout = false
    }

    // MARK: - Reset

    func reset() {
        scannedSerials.removeAll()
        matchedCounts.removeAll()
        extraItems.removeAll()
        unresolvedTags.removeAll()
        processedTags.removeAll()
        checkoutComplete = false
        error = nil
        rfidManager.clearTags()
    }
}
