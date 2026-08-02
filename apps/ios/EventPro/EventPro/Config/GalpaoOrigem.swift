import CoreLocation
import Foundation
import MapKit

// MARK: - Origem fixa da operação
//
// O galpão é o ponto de partida sempre definido do mapa: de lá sai a linha
// até o pin do Evento. Não usa a localização do funcionário.
//
// Coordenadas padrão são placeholder até a MMD informar o ponto oficial.
// Podem ser sobrescritas em UserDefaults (Ajustes futuros ou build local).

enum GalpaoOrigem {
    static let nome = "Galpão MMD"
    /// Endereço operacional informado pela MMD.
    static let endereco = "Rua Doutor Mário Freire, 165"
    static let cidadeUf = "São Paulo, SP"

    private enum Keys {
        static let latitude = "mmd_galpao_latitude"
        static let longitude = "mmd_galpao_longitude"
    }

    /// Geocode OSM da via em Vila Andrade / SP (número 165 sem pin de prédio no OSM).
    /// Latitude/longitude padrão: -23.6184428, -46.7058853.
    private static let defaultLatitude = -23.6184428
    private static let defaultLongitude = -46.7058853

    static var latitude: Double {
        get {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: Keys.latitude) != nil {
                return defaults.double(forKey: Keys.latitude)
            }
            return defaultLatitude
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.latitude) }
    }

    static var longitude: Double {
        get {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: Keys.longitude) != nil {
                return defaults.double(forKey: Keys.longitude)
            }
            return defaultLongitude
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.longitude) }
    }

    static var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Pontos da linha galpão → destino (curva leve, sem MKDirections).
    static func routeCoordinates(to destination: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        let origin = coordinate
        let mid = CLLocationCoordinate2D(
            latitude: (origin.latitude + destination.latitude) / 2
                + (destination.longitude - origin.longitude) * 0.06,
            longitude: (origin.longitude + destination.longitude) / 2
                - (destination.latitude - origin.latitude) * 0.06
        )
        return [origin, mid, destination]
    }

    /// Região que enquadra origem e destino com margem.
    static func region(containing destination: CLLocationCoordinate2D) -> MKCoordinateRegion {
        let origin = coordinate
        let minLat = min(origin.latitude, destination.latitude)
        let maxLat = max(origin.latitude, destination.latitude)
        let minLng = min(origin.longitude, destination.longitude)
        let maxLng = max(origin.longitude, destination.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.7, 0.02),
            longitudeDelta: max((maxLng - minLng) * 1.7, 0.02)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
