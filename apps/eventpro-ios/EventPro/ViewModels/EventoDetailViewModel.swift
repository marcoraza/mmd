import Foundation
import os.log

/// Ficha do Evento no mobile: resumo do servidor mais o packing list.
@MainActor
final class EventoDetailViewModel: ObservableObject {

    @Published private(set) var resumo: EventoResumo?
    @Published private(set) var packing: [PackingListItem] = []
    @Published private(set) var isLoading = false
    @Published var error: String?

    let evento: Project
    private let apiClient: APIClient
    private let logger = Logger(subsystem: "com.emdash.eventpro", category: "EventoDetail")

    init(evento: Project, apiClient: APIClient) {
        self.evento = evento
        self.apiClient = apiClient
    }

    /// Status mais recente: o do resumo quando ele chega, senão o da lista.
    var status: StatusProjeto {
        resumo?.status ?? evento.status
    }

    var podeFazerCheckout: Bool { status.permiteCheckout }
    var podeFazerRetorno: Bool { status.permiteRetorno }

    var totalItens: Int {
        resumo?.packing.itensTotal ?? packing.reduce(0) { $0 + $1.quantidade }
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let novoResumo = await fetchResumo()
        let novoPacking = await fetchPacking()

        if let novoResumo { resumo = novoResumo }
        if let novoPacking { packing = novoPacking }

        if novoResumo == nil && novoPacking == nil {
            error = error ?? "Não foi possível carregar o evento."
        }
    }

    private func fetchResumo() async -> EventoResumo? {
        do {
            return try await apiClient.fetchEventoResumo(projectId: evento.id)
        } catch {
            self.error = error.localizedDescription
            logger.error("Falha no resumo: \(String(describing: error))")
            return nil
        }
    }

    private func fetchPacking() async -> [PackingListItem]? {
        do {
            return try await apiClient.fetchPackingList(projectId: evento.id)
        } catch {
            logger.error("Falha no packing: \(String(describing: error))")
            return nil
        }
    }
}
