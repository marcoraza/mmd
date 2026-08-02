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
    static let cidadeUf = "Morumbi, São Paulo, SP"

    private enum Keys {
        static let latitude = "mmd_galpao_latitude"
        static let longitude = "mmd_galpao_longitude"
    }

    /// Geocode da via em Morumbi / Vila Andrade (SP). Número 165 sem pin de
    /// prédio no OSM; ponto = centroide da Rua Doutor Mário Freire (CEP 05690-050).
    private static let defaultLatitude = -23.6177585
    private static let defaultLongitude = -46.7069985

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

    /// Linha galpão → destino com curva de composição (mockup).
    static func routeCoordinates(to destination: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        MapRouteComposition.routeCoordinates(from: coordinate, to: destination)
    }

    /// Região do card: origem e pin nos cantos com margem, como no mockup.
    static func region(
        containing destination: CLLocationCoordinate2D,
        aspectWidthOverHeight: Double = MapRouteComposition.compactAspect
    ) -> MKCoordinateRegion {
        MapRouteComposition.region(
            origin: coordinate,
            destination: destination,
            aspectWidthOverHeight: aspectWidthOverHeight
        )
    }
}
