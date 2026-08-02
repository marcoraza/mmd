import CoreLocation
import Foundation

// MARK: - Pin de destino

/// Coordenada operacional do pin de chegada do Evento.
struct DestinoPin: Equatable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
    var confirmadoEm: Date?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(latitude: Double, longitude: Double, confirmadoEm: Date? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.confirmadoEm = confirmadoEm
    }
}

// MARK: - Sugestão de busca (Apple Maps via adaptador)

struct PlaceSuggestion: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double

    var pin: DestinoPin {
        DestinoPin(latitude: latitude, longitude: longitude, confirmadoEm: Date())
    }
}

// MARK: - Subconjunto da ficha (endereço humano)

/// Apenas o bloco de endereço da ficha do Evento. Não espelha a ficha inteira.
struct EventoFichaEndereco: Codable, Hashable, Sendable {
    var local: String?
    var endereco: String?
    var cidadeUf: String?
    var referenciaAcesso: String?

    enum CodingKeys: String, CodingKey {
        case local
        case endereco
        case cidadeUf
        case referenciaAcesso
    }
}

struct EventoFichaDestino: Codable, Hashable, Sendable {
    var endereco: EventoFichaEndereco?
}

// MARK: - Role

enum UserRole: String, Codable, Sendable {
    case viewer
    case editor
    case admin

    var canEditDestino: Bool {
        self == .editor || self == .admin
    }
}
