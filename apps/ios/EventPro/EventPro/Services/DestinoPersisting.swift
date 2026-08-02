import Foundation

// MARK: - Seam de persistência do pin

@MainActor
protocol DestinoPersisting: AnyObject {
    func saveDestino(
        projectId: UUID,
        latitude: Double,
        longitude: Double,
        confirmadoEm: Date
    ) async throws

    func clearDestino(projectId: UUID) async throws
}

// MARK: - Adaptador PostgREST via APIClient

@MainActor
final class APIClientDestinoStore: DestinoPersisting {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func saveDestino(
        projectId: UUID,
        latitude: Double,
        longitude: Double,
        confirmadoEm: Date
    ) async throws {
        try await client.updateEventoDestino(
            projectId: projectId,
            latitude: latitude,
            longitude: longitude,
            confirmadoEm: confirmadoEm
        )
    }

    func clearDestino(projectId: UUID) async throws {
        try await client.updateEventoDestino(
            projectId: projectId,
            latitude: nil,
            longitude: nil
        )
    }
}
