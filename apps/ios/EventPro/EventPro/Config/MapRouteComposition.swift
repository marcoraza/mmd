import CoreLocation
import Foundation
import MapKit

// MARK: - Rota galpão → pin (visual do mockup, geografia real)
//
// Mockup: 7 RotaVariante com curvas diferentes por evento + balão de km no pin.
// Aqui a linha muda de verdade com o destino (direção, distância e variante
// estável derivada das coords). O enquadramento é geográfico com padding,
// não força todos os destinos no mesmo canto do card.

enum MapRouteComposition {

    /// Aspecto do card compacto (largura / altura 212).
    static let compactAspect: Double = 390.0 / 212.0

    /// Offsets de controle no espírito das 7 RotaVariante do mockup.
    /// (along1, perp1, along2, perp2) em fração do vetor origem→destino.
    private static let variantes: [(Double, Double, Double, Double)] = [
        (0.28, 0.20, 0.72, -0.14),
        (0.32, 0.12, 0.68, -0.20),
        (0.24, 0.26, 0.76, -0.08),
        (0.36, 0.10, 0.64, -0.22),
        (0.30, 0.16, 0.70, -0.16),
        (0.22, 0.28, 0.78, -0.06),
        (0.27, 0.22, 0.73, -0.12),
    ]

    // MARK: - Distância

    static func distanceMeters(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(
                from: CLLocation(
                    latitude: destination.latitude,
                    longitude: destination.longitude
                )
            )
    }

    static func distanceKilometers(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> Double {
        distanceMeters(from: origin, to: destination) / 1000.0
    }

    /// Km exibido no balão (inteiro, mínimo 1 se houver pin distinto).
    static func displayKilometers(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> Int {
        let km = distanceKilometers(from: origin, to: destination)
        if km < 0.5 { return 1 }
        return max(1, Int(km.rounded()))
    }

    // MARK: - Região (geografia natural)

    static func region(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        aspectWidthOverHeight: Double = compactAspect
    ) -> MKCoordinateRegion {
        let minLat = min(origin.latitude, destination.latitude)
        let maxLat = max(origin.latitude, destination.latitude)
        let minLng = min(origin.longitude, destination.longitude)
        let maxLng = max(origin.longitude, destination.longitude)

        // Centro levemente puxado pro destino (pin é o herói, como no mockup).
        let center = CLLocationCoordinate2D(
            latitude: origin.latitude * 0.42 + destination.latitude * 0.58,
            longitude: origin.longitude * 0.42 + destination.longitude * 0.58
        )

        let rawLat = max(maxLat - minLat, 0.008)
        let rawLng = max(maxLng - minLng, 0.008)
        // Padding generoso: linha e balão não colam na borda.
        var latDelta = rawLat * 2.15
        var lngDelta = rawLng * 2.15

        let aspect = max(aspectWidthOverHeight, 0.5)
        let cosLat = max(cos(center.latitude * .pi / 180), 0.2)
        let visualW = lngDelta * cosLat
        let visualH = latDelta
        if visualW / visualH < aspect {
            lngDelta = (aspect * visualH) / cosLat
        } else {
            latDelta = visualW / aspect
        }

        // Garante que os dois pontos cabem com folga.
        latDelta = max(latDelta, abs(destination.latitude - origin.latitude) * 2.0 + 0.01)
        lngDelta = max(lngDelta, abs(destination.longitude - origin.longitude) * 2.0 + 0.01)
        latDelta = max(latDelta, 0.018)
        lngDelta = max(lngDelta, 0.018)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
        )
    }

    // MARK: - Curva (varia com o destino)

    /// Índice estável 0..<7 a partir do destino (cada local tem “sua” curva).
    static func variantIndex(for destination: CLLocationCoordinate2D) -> Int {
        let h = abs(destination.latitude * 7919.13 + destination.longitude * 104_729.17)
        let scaled = Int((h * 10_000).rounded(.towardZero))
        return abs(scaled) % variantes.count
    }

    /// Polyline cúbica amostrada; forma muda com direção, distância e variante.
    static func routeCoordinates(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        samples: Int = 32
    ) -> [CLLocationCoordinate2D] {
        let count = max(samples, 12)
        let vLat = destination.latitude - origin.latitude
        let vLng = destination.longitude - origin.longitude
        let len = max(sqrt(vLat * vLat + vLng * vLng), 0.00001)
        let nLat = -vLng / len
        let nLng = vLat / len

        let variant = variantes[variantIndex(for: destination)]
        let km = distanceKilometers(from: origin, to: destination)
        // Distâncias longas: arco um pouco mais aberto; curtas: mais contido.
        let distanceScale = min(max(km / 28.0, 0.55), 1.65)

        let (a1, p1, a2, p2) = variant
        let c1 = CLLocationCoordinate2D(
            latitude: origin.latitude + vLat * a1 + nLat * len * p1 * distanceScale,
            longitude: origin.longitude + vLng * a1 + nLng * len * p1 * distanceScale
        )
        let c2 = CLLocationCoordinate2D(
            latitude: origin.latitude + vLat * a2 + nLat * len * p2 * distanceScale,
            longitude: origin.longitude + vLng * a2 + nLng * len * p2 * distanceScale
        )

        var points: [CLLocationCoordinate2D] = []
        points.reserveCapacity(count + 1)
        for i in 0...count {
            let t = Double(i) / Double(count)
            points.append(cubic(t: t, p0: origin, p1: c1, p2: c2, p3: destination))
        }
        return points
    }

    // MARK: - Bezier cúbico

    private static func cubic(
        t: Double,
        p0: CLLocationCoordinate2D,
        p1: CLLocationCoordinate2D,
        p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        let u = 1 - t
        let uu = u * u
        let tt = t * t
        let lat = uu * u * p0.latitude
            + 3 * uu * t * p1.latitude
            + 3 * u * tt * p2.latitude
            + tt * t * p3.latitude
        let lng = uu * u * p0.longitude
            + 3 * uu * t * p1.longitude
            + 3 * u * tt * p2.longitude
            + tt * t * p3.longitude
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}
