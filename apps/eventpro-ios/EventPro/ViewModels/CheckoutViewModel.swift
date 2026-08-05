import Foundation
import Combine
import os.log

// MARK: - PackingItemValidation

enum PackingItemValidation: Equatable {
    case pending
    case complete
    case over
}

// MARK: - CheckoutViewModel

/// Fluxo de check-out: conferir o packing list por scan e disparar a saída.
///
/// O check-out em si é decidido no servidor (`checkout_projeto` /
/// `checkout_projeto_com_override`): a conferência aqui é o que o operador vê,
/// não a fonte da verdade da alocação.
@MainActor
final class CheckoutViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) var packingListItems: [PackingListItem] = []
    @Published private(set) var scannedSerials: [UUID: ResolvedItem] = [:]
    @Published private(set) var matchedCounts: [UUID: Int] = [:]
    @Published private(set) var extraItems: [ResolvedItem] = []
    @Published private(set) var unresolvedTags: [String] = []
    @Published var scanMethod: MetodoScan = .rfid
    @Published private(set) var isLoading = false
    @Published private(set) var isProcessingCheckout = false
    @Published private(set) var checkoutComplete = false
    @Published private(set) var resultado: CheckoutProjectResponse?
    @Published var error: String?

    // MARK: - Derivados

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

    // MARK: - Dependências

    let project: Project
    private let apiClient: APIClient
    private let rfidManager: RFIDManager
    private let logger = Logger(subsystem: "com.emdash.eventpro", category: "Checkout")

    private var cancellables = Set<AnyCancellable>()
    private var processedTags = Set<String>()

    // MARK: - Init

    init(project: Project, apiClient: APIClient, rfidManager: RFIDManager) {
        self.project = project
        self.apiClient = apiClient
        self.rfidManager = rfidManager
        subscribeToTags()
    }

    // MARK: - Packing list

    func loadPackingList() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            packingListItems = try await apiClient.fetchPackingList(projectId: project.id)
            logger.info("Packing list com \(self.packingListItems.count) linhas")
        } catch {
            self.error = error.localizedDescription
            logger.error("Falha no packing list: \(String(describing: error))")
        }
    }

    // MARK: - Tags

    private func subscribeToTags() {
        rfidManager.$tagReads
            .removeDuplicates()
            .sink { [weak self] reads in
                self?.processNewTags(reads)
            }
            .store(in: &cancellables)
    }

    private func processNewTags(_ reads: [RFIDTagRead]) {
        let novos = reads.filter { !processedTags.contains($0.tag) }
        guard !novos.isEmpty else { return }

        processedTags.formUnion(novos.map(\.tag))

        Task { [weak self] in
            await self?.resolveAndMatch(novos)
        }
    }

    // MARK: - QR

    func processQRCode(_ code: String) {
        Task { [weak self] in
            guard let self else { return }
            do {
                guard
                    let serial = try await self.apiClient.resolveQRCode(code),
                    let equipment = serial.item
                else {
                    self.unresolvedTags.append(code)
                    return
                }
                self.matchResolvedItem(ResolvedItem(serialNumber: serial, equipment: equipment))
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Resolução

    private func resolveAndMatch(_ reads: [RFIDTagRead]) async {
        var rssi: [String: Int] = [:]
        for read in reads where read.rssi != nil {
            rssi[read.tag] = read.rssi
        }

        do {
            let result = try await apiClient.recordAndResolveRfidTags(
                tags: reads.map(\.tag),
                contexto: .checkOutEvento,
                projectId: project.id,
                reader: rfidManager.readerRequest(),
                rssiPorTag: rssi
            )
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
        guard scannedSerials[serialId] == nil else { return }
        scannedSerials[serialId] = resolved

        guard let packingItem = packingListItems.first(where: { $0.itemId == resolved.equipment.id }) else {
            extraItems.append(resolved)
            return
        }

        let designados = packingItem.designados
        if !designados.isEmpty && !designados.contains(serialId) {
            // Tipo certo, unidade errada: não conta como cobertura.
            extraItems.append(resolved)
            return
        }

        matchedCounts[packingItem.id, default: 0] += 1
    }

    // MARK: - Validação por linha

    func validationState(for packingItem: PackingListItem) -> PackingItemValidation {
        let matched = matchedCounts[packingItem.id] ?? 0
        guard matched >= packingItem.quantidade else { return .pending }
        return matched > packingItem.quantidade ? .over : .complete
    }

    // MARK: - Finalizar

    func finalizeCheckout(overrideReason: String? = nil) async {
        isProcessingCheckout = true
        error = nil
        defer { isProcessingCheckout = false }

        do {
            let result = try await apiClient.checkoutProject(
                projectId: project.id,
                metodoScan: scanMethod,
                overrideReason: overrideReason
            )
            resultado = result
            checkoutComplete = true
            logger.info("Check-out concluído: \(result.count) seriais")
        } catch {
            self.error = error.localizedDescription
            logger.error("Check-out falhou: \(String(describing: error))")
        }
    }

    // MARK: - Reset

    func reset() {
        scannedSerials.removeAll()
        matchedCounts.removeAll()
        extraItems.removeAll()
        unresolvedTags.removeAll()
        processedTags.removeAll()
        checkoutComplete = false
        resultado = nil
        error = nil
        rfidManager.clearTags()
    }
}
