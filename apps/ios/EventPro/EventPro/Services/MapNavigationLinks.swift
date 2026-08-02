import CoreLocation
import Foundation
import UIKit

// MARK: - Links de navegação (galpão → destino)

enum MapNavigationApp: String, CaseIterable, Identifiable {
    case appleMaps
    case googleMaps
    case waze

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleMaps: return "Apple Maps"
        case .googleMaps: return "Google Maps"
        case .waze: return "Waze"
        }
    }
}

enum MapNavigationLinks {

    /// URLs de navegação do galpão até o destino.
    /// Preferência: deep link do app; fallback https quando o app não está instalado.
    static func urls(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        destinationName: String
    ) -> [(app: MapNavigationApp, url: URL)] {
        let oLat = origin.latitude
        let oLng = origin.longitude
        let dLat = destination.latitude
        let dLng = destination.longitude
        let name = destinationName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Destino"

        var result: [(MapNavigationApp, URL)] = []

        // Apple Maps: saddr/daddr
        if let apple = URL(string: "http://maps.apple.com/?saddr=\(oLat),\(oLng)&daddr=\(dLat),\(dLng)&dirflg=d") {
            result.append((.appleMaps, apple))
        }

        // Google Maps app, senão URL universal
        if let gmaps = URL(string: "comgooglemaps://?saddr=\(oLat),\(oLng)&daddr=\(dLat),\(dLng)&directionsmode=driving"),
           UIApplication.shared.canOpenURL(gmaps) {
            result.append((.googleMaps, gmaps))
        } else if let gweb = URL(string: "https://www.google.com/maps/dir/?api=1&origin=\(oLat),\(oLng)&destination=\(dLat),\(dLng)&travelmode=driving") {
            result.append((.googleMaps, gweb))
        }

        // Waze: navega até o destino (origem fica a cargo do app do motorista)
        if let waze = URL(string: "waze://?ll=\(dLat),\(dLng)&navigate=yes"),
           UIApplication.shared.canOpenURL(waze) {
            result.append((.waze, waze))
        } else if let wweb = URL(string: "https://waze.com/ul?ll=\(dLat),\(dLng)&navigate=yes&q=\(name)") {
            result.append((.waze, wweb))
        }

        return result
    }

    /// Versão pura para testes (sem consultar canOpenURL).
    static func urlTemplates(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> [MapNavigationApp: String] {
        let oLat = origin.latitude
        let oLng = origin.longitude
        let dLat = destination.latitude
        let dLng = destination.longitude
        return [
            .appleMaps: "http://maps.apple.com/?saddr=\(oLat),\(oLng)&daddr=\(dLat),\(dLng)&dirflg=d",
            .googleMaps: "https://www.google.com/maps/dir/?api=1&origin=\(oLat),\(oLng)&destination=\(dLat),\(dLng)&travelmode=driving",
            .waze: "https://waze.com/ul?ll=\(dLat),\(dLng)&navigate=yes",
        ]
    }

    @MainActor
    static func open(
        _ app: MapNavigationApp,
        from origin: CLLocationCoordinate2D = GalpaoOrigem.coordinate,
        to destination: CLLocationCoordinate2D,
        destinationName: String
    ) {
        let links = urls(from: origin, to: destination, destinationName: destinationName)
        guard let match = links.first(where: { $0.app == app }) else { return }
        UIApplication.shared.open(match.url)
    }
}
