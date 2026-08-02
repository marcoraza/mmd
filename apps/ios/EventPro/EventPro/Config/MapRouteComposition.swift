import CoreGraphics
import CoreLocation
import Foundation
import MapKit

// MARK: - Composição da rota no card (mockup Event Pro)
//
// Design ilustrativo (RotaVariante + HTML):
// - origem no canto inferior esquerdo (~12–18% x, ~78–88% y)
// - pin no canto superior direito (~78–86% x, ~16–30% y)
// - curva diagonal com arco, gradiente branco origem→destino
//
// Com mapa real (norte para cima) escolhemos a diagonal natural da geografia
// (mesmo espírito: pontos nos cantos com margem 16%, linha atravessando o card).

enum MapRouteComposition {

    /// Margem do card (mockup: pontos longe da borda).
    static let margin: Double = 0.16

    /// Aspecto do card compacto (largura / altura 212).
    static let compactAspect: Double = 390.0 / 212.0

    // MARK: - Região

    static func region(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        aspectWidthOverHeight: Double = compactAspect
    ) -> MKCoordinateRegion {
        let anchors = screenAnchors(from: origin, to: destination)
        let oS = anchors.origin
        let dS = anchors.destination

        let dy = dS.y - oS.y
        let dx = dS.x - oS.x

        // Mapeamento MapKit (norte no topo):
        // lat(y) = center.lat + latDelta/2 - y * latDelta
        // lng(x) = center.lng - lngDelta/2 + x * lngDelta
        var latDelta: Double
        var lngDelta: Double

        if abs(dy) > 0.001 {
            latDelta = (origin.latitude - destination.latitude) / dy
        } else {
            latDelta = max(abs(origin.latitude - destination.latitude) * 2.6, 0.014)
        }

        if abs(dx) > 0.001 {
            lngDelta = (destination.longitude - origin.longitude) / dx
        } else {
            lngDelta = max(abs(origin.longitude - destination.longitude) * 2.6, 0.014)
        }

        latDelta = max(abs(latDelta), 0.014)
        lngDelta = max(abs(lngDelta), 0.014)

        // Centro a partir da âncora da origem.
        let centerLat = origin.latitude - latDelta / 2 + oS.y * latDelta
        let centerLng = origin.longitude + lngDelta / 2 - oS.x * lngDelta
        var region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
        )

        // Se o destino caiu fora (sinal/float), expande o span mantendo o centro.
        region = expandSpanIfNeeded(region, points: [origin, destination], edgePadding: 0.04)

        // Aspecto do card (evita linha esmagada).
        region = applyAspect(region, widthOverHeight: aspectWidthOverHeight)
        region = expandSpanIfNeeded(region, points: [origin, destination], edgePadding: 0.04)

        return region
    }

    // MARK: - Curva da linha

    /// Polyline em arco (Bezier amostrado), no espírito do path Q do mockup.
    static func routeCoordinates(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        samples: Int = 28
    ) -> [CLLocationCoordinate2D] {
        let count = max(samples, 8)
        let midLat = (origin.latitude + destination.latitude) / 2
        let midLng = (origin.longitude + destination.longitude) / 2
        let vLat = destination.latitude - origin.latitude
        let vLng = destination.longitude - origin.longitude
        let len = max(sqrt(vLat * vLat + vLng * vLng), 0.00001)
        // Arco ~22% do comprimento (mockup midX+8 / midY-10 em card 100).
        let bow = 0.22
        let control = CLLocationCoordinate2D(
            latitude: midLat + (-vLng / len) * len * bow,
            longitude: midLng + (vLat / len) * len * bow
        )

        var points: [CLLocationCoordinate2D] = []
        points.reserveCapacity(count + 1)
        for i in 0...count {
            let t = Double(i) / Double(count)
            let u = 1 - t
            let lat = u * u * origin.latitude
                + 2 * u * t * control.latitude
                + t * t * destination.latitude
            let lng = u * u * origin.longitude
                + 2 * u * t * control.longitude
                + t * t * destination.longitude
            points.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        return points
    }

    // MARK: - Âncoras de tela

    /// Cantos com margem 16% na diagonal natural origem→destino.
    static func screenAnchors(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> (origin: (x: Double, y: Double), destination: (x: Double, y: Double)) {
        let m = margin
        let f = 1 - margin
        let dLat = destination.latitude - origin.latitude
        let dLng = destination.longitude - origin.longitude

        // x cresce a leste; y de tela cresce ao sul.
        let originX = dLng >= 0 ? m : f
        let destX = dLng >= 0 ? f : m
        // Destino ao norte → origem embaixo (y alto), destino em cima (y baixo).
        let originY = dLat >= 0 ? f : m
        let destY = dLat >= 0 ? m : f

        return (
            origin: (originX, originY),
            destination: (destX, destY)
        )
    }

    // MARK: - Helpers

    /// Expande o span se algum ponto estiver perto demais da borda; mantém o centro.
    private static func expandSpanIfNeeded(
        _ region: MKCoordinateRegion,
        points: [CLLocationCoordinate2D],
        edgePadding: Double
    ) -> MKCoordinateRegion {
        let c = region.center
        var latHalf = region.span.latitudeDelta / 2
        var lngHalf = region.span.longitudeDelta / 2
        let padLat = max(region.span.latitudeDelta * edgePadding, 0.001)
        let padLng = max(region.span.longitudeDelta * edgePadding, 0.001)

        for p in points {
            latHalf = max(latHalf, abs(p.latitude - c.latitude) + padLat)
            lngHalf = max(lngHalf, abs(p.longitude - c.longitude) + padLng)
        }

        return MKCoordinateRegion(
            center: c,
            span: MKCoordinateSpan(
                latitudeDelta: max(latHalf * 2, 0.014),
                longitudeDelta: max(lngHalf * 2, 0.014)
            )
        )
    }

    private static func applyAspect(
        _ region: MKCoordinateRegion,
        widthOverHeight: Double
    ) -> MKCoordinateRegion {
        let aspect = max(widthOverHeight, 0.5)
        let cosLat = max(cos(region.center.latitude * .pi / 180), 0.2)
        var latDelta = region.span.latitudeDelta
        var lngDelta = region.span.longitudeDelta
        let visualWidth = lngDelta * cosLat
        let visualHeight = max(latDelta, 0.00001)
        let currentAspect = visualWidth / visualHeight

        if currentAspect < aspect {
            lngDelta = (aspect * visualHeight) / cosLat
        } else {
            latDelta = visualWidth / aspect
        }

        return MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta, 0.014),
                longitudeDelta: max(lngDelta, 0.014)
            )
        )
    }
}
