import Foundation
import os.log

/// Lista de Eventos abertos e o resumo de cada um.
@MainActor
final class EventosViewModel: ObservableObject {

    @Published private(set) var eventos: [Project] = []
    @Published private(set) var resumos: [UUID: EventoResumo] = [:]
    @Published private(set) var isLoading = false
    @Published var error: String?

    private let apiClient: APIClient
    private let logger = Logger(subsystem: "com.emdash.eventpro", category: "Eventos")

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            eventos = try await apiClient.fetchProjects(status: StatusProjeto.abertos)
            logger.info("Carregados \(self.eventos.count) eventos abertos")
        } catch {
            self.error = error.localizedDescription
            logger.error("Falha ao carregar eventos: \(String(describing: error))")
        }
    }

    /// Carrega o resumo pelo endpoint dedicado, em vez de agregar packing e
    /// seriais no cliente como o app legado fazia.
    func loadResumo(for evento: Project) async {
        do {
            resumos[evento.id] = try await apiClient.fetchEventoResumo(projectId: evento.id)
        } catch {
            // Resumo é enriquecimento: falhar aqui não pode apagar a lista.
            logger.error("Falha ao carregar resumo de \(evento.id.uuidString): \(String(describing: error))")
        }
    }

    func resumo(for evento: Project) -> EventoResumo? {
        resumos[evento.id]
    }
}
