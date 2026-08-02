import Foundation
import MapKit

// MARK: - Seam de busca

@MainActor
protocol PlaceSearching: AnyObject {
    func search(query: String) async throws -> [PlaceSuggestion]
}

// MARK: - Adaptador MapKit

/// Busca local do Apple Maps. Não pede localização do aparelho.
@MainActor
final class MapKitPlaceSearcher: PlaceSearching {

    func search(query: String) async throws -> [PlaceSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.address, .pointOfInterest]

        let search = MKLocalSearch(request: request)
        let response: MKLocalSearch.Response
        do {
            response = try await search.start()
        } catch {
            throw PlaceSearchError.failed(error.localizedDescription)
        }

        return response.mapItems.compactMap { item -> PlaceSuggestion? in
            let placemark = item.placemark
            guard let location = placemark.location else { return nil }

            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = (name?.isEmpty == false) ? name! : "Local"

            let addressParts = [
                placemark.thoroughfare.map { street in
                    if let number = placemark.subThoroughfare {
                        return "\(street), \(number)"
                    }
                    return street
                },
                placemark.locality,
                placemark.administrativeArea,
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

            let address = addressParts.isEmpty
                ? (placemark.title ?? title)
                : addressParts.joined(separator: ", ")

            let id = [
                title,
                address,
                String(location.coordinate.latitude),
                String(location.coordinate.longitude),
            ].joined(separator: "|")

            return PlaceSuggestion(
                id: id,
                name: title,
                address: address,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        }
    }
}

enum PlaceSearchError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            return message
        }
    }
}
