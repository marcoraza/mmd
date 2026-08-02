import XCTest
@testable import EventPro

@MainActor
final class EventLocationViewModelTests: XCTestCase {

    private var searcher: MockPlaceSearcher!
    private var store: MockDestinoStore!
    private var vm: EventLocationViewModel!

    override func setUp() async throws {
        try await super.setUp()
        searcher = MockPlaceSearcher()
        store = MockDestinoStore()
        vm = EventLocationViewModel(searcher: searcher, store: store, canEdit: true)
    }

    // MARK: - Helpers

    private func project(
        id: UUID = UUID(),
        nome: String = "Evento",
        local: String? = "Rosewood",
        lat: Double? = nil,
        lng: Double? = nil,
        fichaLocal: String? = nil,
        fichaEndereco: String? = nil,
        fichaCidade: String? = nil
    ) -> Project {
        var p = Project(
            id: id,
            nome: nome,
            local: local,
            status: .confirmado,
            destinoLatitude: lat,
            destinoLongitude: lng,
            destinoConfirmadoEm: (lat != nil ? Date() : nil)
        )
        if fichaLocal != nil || fichaEndereco != nil || fichaCidade != nil {
            p.fichaEvento = EventoFichaDestino(
                endereco: EventoFichaEndereco(
                    local: fichaLocal,
                    endereco: fichaEndereco,
                    cidadeUf: fichaCidade
                )
            )
        }
        return p
    }

    private func suggestion(
        name: String = "Rosewood São Paulo",
        lat: Double = -23.561414,
        lng: Double = -46.655881
    ) -> PlaceSuggestion {
        PlaceSuggestion(
            id: "\(name)|\(lat)|\(lng)",
            name: name,
            address: "Alameda Santos, SP",
            latitude: lat,
            longitude: lng
        )
    }

    // MARK: - Prefill

    func testBindPrefillsQueryFromFicha() {
        let p = project(
            fichaLocal: "Rosewood",
            fichaEndereco: "Alameda Santos 2222",
            fichaCidade: "São Paulo, SP"
        )
        vm.bind(project: p, canEdit: true)
        XCTAssertEqual(vm.query, "Rosewood, Alameda Santos 2222, São Paulo, SP")
        XCTAssertTrue(vm.canEdit)
    }

    // MARK: - Select suggestion

    func testSelectSuggestionPublishesPinAndSaves() async {
        let id = UUID()
        vm.bind(project: project(id: id), canEdit: true)
        searcher.results = [suggestion()]

        await vm.selectSuggestion(suggestion())

        XCTAssertEqual(vm.pin?.latitude ?? 0, -23.561414, accuracy: 0.000001)
        XCTAssertEqual(vm.pin?.longitude ?? 0, -46.655881, accuracy: 0.000001)
        XCTAssertEqual(store.saves.count, 1)
        XCTAssertEqual(store.saves.first?.projectId, id)
        XCTAssertEqual(vm.toast, "Local atualizado")
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func testSelectSuggestionWithoutEditDoesNothing() async {
        vm.bind(project: project(), canEdit: false)
        await vm.selectSuggestion(suggestion())
        XCTAssertNil(vm.pin)
        XCTAssertTrue(store.saves.isEmpty)
    }

    // MARK: - Stale search

    func testStaleSearchResultIsIgnored() async {
        let id = UUID()
        vm.bind(project: project(id: id), canEdit: true)

        searcher.results = [suggestion(name: "Lento", lat: 1, lng: 1)]
        searcher.delayNanoseconds = 200_000_000

        let slow = Task { await vm.searchNow() }
        try? await Task.sleep(nanoseconds: 20_000_000)

        searcher.delayNanoseconds = 0
        searcher.results = [suggestion(name: "Rapido", lat: 2, lng: 2)]
        await vm.searchNow()
        await slow.value

        XCTAssertEqual(vm.suggestions.count, 1)
        XCTAssertEqual(vm.suggestions.first?.name, "Rapido")
    }

    // MARK: - Search failure preserves pin

    func testSearchFailurePreservesPin() async {
        let p = project(lat: -23.5, lng: -46.6)
        vm.bind(project: p, canEdit: true)
        XCTAssertNotNil(vm.pin)

        searcher.error = PlaceSearchError.failed("offline")
        await vm.searchNow()

        XCTAssertNotNil(vm.pin)
        XCTAssertEqual(vm.pin?.latitude ?? 0, -23.5, accuracy: 0.0001)
        XCTAssertNotNil(vm.searchError)
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func testEmptyResultsPreservePin() async {
        let p = project(lat: -23.5, lng: -46.6)
        vm.bind(project: p, canEdit: true)
        searcher.results = []
        await vm.searchNow()
        XCTAssertTrue(vm.emptyResults)
        XCTAssertNotNil(vm.pin)
    }

    // MARK: - Event switch mid-flight

    func testSwitchingEventDropsInFlightSearch() async {
        let a = project(id: UUID(), nome: "A")
        let b = project(id: UUID(), nome: "B")
        vm.bind(project: a, canEdit: true)

        searcher.results = [suggestion(name: "A-result")]
        searcher.delayNanoseconds = 150_000_000
        let slow = Task { await vm.searchNow() }

        try? await Task.sleep(nanoseconds: 20_000_000)
        vm.bind(project: b, canEdit: true)
        await slow.value

        XCTAssertTrue(vm.suggestions.isEmpty)
        XCTAssertEqual(vm.projectId, b.id)
    }

    // MARK: - Camera end + race

    func testCameraIdlePersistsFinalCoordinate() async {
        let id = UUID()
        vm.bind(project: project(id: id, lat: -23.0, lng: -46.0), canEdit: true)
        vm.beginMapEdit()

        await vm.commitCameraCenter(latitude: -23.1, longitude: -46.1)

        XCTAssertEqual(store.saves.count, 1)
        XCTAssertEqual(store.saves.last?.latitude ?? 0, -23.1, accuracy: 0.0001)
        XCTAssertEqual(vm.toast, "Local atualizado")
        XCTAssertTrue(vm.canUndo)
    }

    func testRapidCameraEditsKeepLatestSave() async {
        let id = UUID()
        vm.bind(project: project(id: id, lat: -23.0, lng: -46.0), canEdit: true)
        vm.beginMapEdit()

        // Primeira gravação fica presa até liberarmos; a segunda termina antes.
        store.holdNextSave = true
        let first = Task {
            await vm.commitCameraCenter(latitude: -23.1, longitude: -46.1)
        }

        // Espera a primeira entrar no hold.
        for _ in 0..<50 where store.waitingSaves == 0 {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertEqual(store.waitingSaves, 1)

        await vm.commitCameraCenter(latitude: -23.2, longitude: -46.2)
        XCTAssertEqual(vm.pin?.latitude ?? 0, -23.2, accuracy: 0.0001)
        XCTAssertEqual(store.saves.last?.latitude ?? 0, -23.2, accuracy: 0.0001)

        store.releaseHeldSaves()
        await first.value

        // Pin permanece o da geração mais nova mesmo após a gravação atrasada.
        XCTAssertEqual(vm.pin?.latitude ?? 0, -23.2, accuracy: 0.0001)
    }

    // MARK: - Undo + failure

    func testUndoRestoresPreviousPin() async {
        let id = UUID()
        vm.bind(project: project(id: id, lat: -23.0, lng: -46.0), canEdit: true)
        await vm.selectSuggestion(suggestion(lat: -23.5, lng: -46.5))
        XCTAssertTrue(vm.canUndo)

        await vm.undo()

        XCTAssertEqual(vm.pin?.latitude ?? 0, -23.0, accuracy: 0.0001)
        XCTAssertEqual(store.saves.last?.latitude ?? 0, -23.0, accuracy: 0.0001)
        XCTAssertFalse(vm.canUndo)
    }

    func testSaveFailureRestoresPreviousPin() async {
        let id = UUID()
        vm.bind(project: project(id: id, lat: -23.0, lng: -46.0), canEdit: true)
        store.error = APIError.invalidRequest("negado")

        await vm.selectSuggestion(suggestion(lat: -10, lng: -20))

        XCTAssertEqual(vm.pin?.latitude ?? 0, -23.0, accuracy: 0.0001)
        XCTAssertNotNil(vm.saveError)
        XCTAssertNil(vm.toast)
        XCTAssertFalse(vm.canUndo)
    }

    func testViewerCannotBeginEdit() {
        vm.bind(project: project(lat: -23, lng: -46), canEdit: false)
        vm.beginMapEdit()
        XCTAssertFalse(vm.isEditingMap)
    }
}

// MARK: - Mocks

@MainActor
final class MockPlaceSearcher: PlaceSearching {
    var results: [PlaceSuggestion] = []
    var error: Error?
    var delayNanoseconds: UInt64 = 0
    private(set) var calls: [String] = []

    func search(query: String) async throws -> [PlaceSuggestion] {
        calls.append(query)
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let error { throw error }
        return results
    }
}

@MainActor
final class MockDestinoStore: DestinoPersisting {
    struct Save: Equatable {
        let projectId: UUID
        let latitude: Double
        let longitude: Double
    }

    private(set) var saves: [Save] = []
    var error: Error?
    var delayNanoseconds: UInt64 = 0
    var holdNextSave = false
    private(set) var waitingSaves = 0
    private var holdContinuations: [CheckedContinuation<Void, Never>] = []

    func saveDestino(
        projectId: UUID,
        latitude: Double,
        longitude: Double,
        confirmadoEm: Date
    ) async throws {
        if holdNextSave {
            holdNextSave = false
            waitingSaves += 1
            await withCheckedContinuation { cont in
                holdContinuations.append(cont)
            }
            waitingSaves -= 1
        } else if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let error { throw error }
        saves.append(Save(projectId: projectId, latitude: latitude, longitude: longitude))
    }

    func releaseHeldSaves() {
        let pending = holdContinuations
        holdContinuations = []
        for cont in pending {
            cont.resume()
        }
    }

    func clearDestino(projectId: UUID) async throws {
        if let error { throw error }
    }
}
