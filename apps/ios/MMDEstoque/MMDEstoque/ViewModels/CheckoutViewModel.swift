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
    @Published var scannedSerials: [UUID: ResolvedItem] = [:]
    @Published var matchedCounts: [UUID: Int] = [:]
    @Published var extraItems: [ResolvedItem] = []
    @Published var unresolvedTags: [String] = []
    @Published var scanMethod: MetodoScan = .rfid
    @Published var isLoading = false
    @Published var isProcessingCheckout = false
    @Published var checkoutComplete = false
    @Published var error: String?

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

        do {
            packingListItems = try await apiClient.fetchPackingList(projectId: project.id)
            logger.info("Loaded \(self.packingListItems.count) packing list items")
        } catch {
            self.error = error.localizedDescription
            logger.error("Failed to load packing list: \(error)")
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
            let result = try await apiClient.resolveRfidTags(tags)

            for item in result.resolved {
                matchResolvedItem(item)
            }

            unresolvedTags.append(contentsOf: result.unresolved)
        } catch {
            self.error = error.localizedDescription
        }
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
            // Build serial list for API
            let serials = scannedSerials.values.compactMap { resolved -> (serialId: UUID, currentStatus: String, metodoScan: MetodoScan)? in
                // Only include items that are in the packing list
                let isInPackingList = packingListItems.contains { $0.itemId == resolved.equipment.id }
                guard isInPackingList else { return nil }

                return (
                    serialId: resolved.serialNumber.id,
                    currentStatus: resolved.serialNumber.status.rawValue,
                    metodoScan: scanMethod
                )
            }

            try await apiClient.registerCheckout(projectId: project.id, serials: serials)
            try await apiClient.updateProjectStatus(projectId: project.id, status: .emCampo)

            checkoutComplete = true
            logger.info("Checkout finalized: \(serials.count) items")
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
