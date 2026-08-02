import Foundation

// MARK: - EventLocationViewModel
//
// Costura comportamental da localização do Evento: busca, pin automático,
// edição estilo Uber e desfazer. MapKit e PostgREST entram só por seams.

@MainActor
final class EventLocationViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) var projectId: UUID?
    @Published private(set) var displayName: String = ""
    @Published private(set) var addressLine: String = ""
    @Published var query: String = ""
    @Published private(set) var suggestions: [PlaceSuggestion] = []
    @Published private(set) var isSearching = false
    @Published private(set) var searchError: String?
    @Published private(set) var emptyResults = false
    @Published private(set) var pin: DestinoPin?
    @Published private(set) var isSaving = false
    @Published private(set) var saveError: String?
    @Published private(set) var toast: String?
    @Published private(set) var canUndo = false
    @Published private(set) var isEditingMap = false
    @Published private(set) var canEdit = false

    /// Notifica o pai quando o pin persistido muda (agenda / mapa compacto).
    var onPinPersisted: ((UUID, DestinoPin?) -> Void)?

    // MARK: - Private

    private let searcher: PlaceSearching
    private let store: DestinoPersisting
    private var undoPin: DestinoPin?
    private var searchGeneration = 0
    private var saveGeneration = 0
    private var searchTask: Task<Void, Never>?

    // MARK: - Init

    init(
        searcher: PlaceSearching,
        store: DestinoPersisting,
        canEdit: Bool = false
    ) {
        self.searcher = searcher
        self.store = store
        self.canEdit = canEdit
    }

    // MARK: - Bind

    /// Troca o Evento em foco. Invalida buscas e gravações em voo do anterior.
    func bind(project: Project, canEdit: Bool) {
        let switched = project.id != projectId
        self.canEdit = canEdit

        if switched {
            searchGeneration += 1
            saveGeneration += 1
            searchTask?.cancel()
            suggestions = []
            searchError = nil
            emptyResults = false
            saveError = nil
            toast = nil
            canUndo = false
            undoPin = nil
            isEditingMap = false
            isSearching = false
            isSaving = false
        }

        projectId = project.id
        displayName = project.localDisplayName
        addressLine = project.enderecoDisplayLine
        if switched || query.isEmpty {
            query = project.prefillSearchQuery
        }
        pin = project.destinoPin
    }

    // MARK: - Busca

    func scheduleSearch() {
        searchTask?.cancel()
        let generation = searchGeneration + 1
        searchGeneration = generation
        let text = query

        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            await self?.runSearch(query: text, generation: generation)
        }
    }

    func searchNow() async {
        searchTask?.cancel()
        let generation = searchGeneration + 1
        searchGeneration = generation
        await runSearch(query: query, generation: generation)
    }

    private func runSearch(query: String, generation: Int) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            guard generation == searchGeneration else { return }
            suggestions = []
            emptyResults = false
            searchError = nil
            isSearching = false
            return
        }

        isSearching = true
        searchError = nil
        emptyResults = false

        do {
            let results = try await searcher.search(query: trimmed)
            guard generation == searchGeneration else { return }
            suggestions = results
            emptyResults = results.isEmpty
            isSearching = false
        } catch {
            guard generation == searchGeneration else { return }
            // Preserva pin e destino; só reporta falha de busca.
            suggestions = []
            emptyResults = false
            searchError = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            isSearching = false
        }
    }

    // MARK: - Selecionar sugestão (autosave)

    func selectSuggestion(_ suggestion: PlaceSuggestion) async {
        guard canEdit, let projectId else { return }
        let previous = pin
        let next = DestinoPin(
            latitude: suggestion.latitude,
            longitude: suggestion.longitude,
            confirmadoEm: Date()
        )
        pin = next
        suggestions = []
        emptyResults = false
        searchError = nil
        await persist(projectId: projectId, next: next, previous: previous, recordUndo: true)
    }

    // MARK: - Edição estilo Uber

    func beginMapEdit() {
        guard canEdit, pin != nil else { return }
        isEditingMap = true
        toast = nil
        saveError = nil
    }

    func cancelMapEdit() {
        isEditingMap = false
    }

    /// Chamado ao terminar o gesto de câmera (não a cada frame).
    func commitCameraCenter(latitude: Double, longitude: Double) async {
        guard isEditingMap, canEdit, let projectId else { return }
        let previous = pin
        let next = DestinoPin(
            latitude: latitude,
            longitude: longitude,
            confirmadoEm: Date()
        )
        // Mesma coordenada: não grava de novo.
        if let previous,
           abs(previous.latitude - next.latitude) < 0.000001,
           abs(previous.longitude - next.longitude) < 0.000001 {
            return
        }
        pin = next
        await persist(projectId: projectId, next: next, previous: previous, recordUndo: true)
    }

    // MARK: - Desfazer

    func undo() async {
        guard canEdit, canUndo, let projectId, let restored = undoPin else { return }
        let previous = pin
        pin = restored
        canUndo = false
        undoPin = nil
        toast = nil
        await persist(projectId: projectId, next: restored, previous: previous, recordUndo: false)
    }

    func dismissToast() {
        toast = nil
    }

    // MARK: - Persistência

    private func persist(
        projectId: UUID,
        next: DestinoPin,
        previous: DestinoPin?,
        recordUndo: Bool
    ) async {
        let generation = saveGeneration + 1
        saveGeneration = generation
        isSaving = true
        saveError = nil

        do {
            try await store.saveDestino(
                projectId: projectId,
                latitude: next.latitude,
                longitude: next.longitude,
                confirmadoEm: next.confirmadoEm ?? Date()
            )
            // Resposta atrasada: não toca pin, toast nem undo da geração nova.
            guard generation == saveGeneration else { return }
            // Garante pin da geração vencedora (proteção se outra mutação intercalar).
            pin = next
            isSaving = false
            if recordUndo {
                undoPin = previous
                canUndo = previous != nil
                toast = "Local atualizado"
            }
            onPinPersisted?(projectId, next)
        } catch {
            guard generation == saveGeneration else { return }
            // Restaura o último pin confirmado só se esta geração ainda manda.
            pin = previous
            isSaving = false
            saveError = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            canUndo = false
            undoPin = nil
            toast = nil
            onPinPersisted?(projectId, previous)
        }
    }
}
