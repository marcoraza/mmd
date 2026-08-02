import CoreLocation
import MapKit
import XCTest
@testable import EventPro

final class MapRouteCompositionTests: XCTestCase {

    private let galpao = CLLocationCoordinate2D(latitude: -23.6177585, longitude: -46.7069985)
    /// NE do galpão (Rosewood-ish).
    private let destNE = CLLocationCoordinate2D(latitude: -23.5614, longitude: -46.6559)
    /// SW do galpão.
    private let destSW = CLLocationCoordinate2D(latitude: -23.6500, longitude: -46.7400)

    func testAnchorsPreferBottomLeftToTopRightWhenDestIsNE() {
        let a = MapRouteComposition.screenAnchors(from: galpao, to: destNE)
        // origem embaixo-esquerda, destino em cima-direita
        XCTAssertLessThan(a.origin.x, a.destination.x)
        XCTAssertGreaterThan(a.origin.y, a.destination.y)
        XCTAssertEqual(a.origin.x, MapRouteComposition.margin, accuracy: 0.001)
        XCTAssertEqual(a.destination.x, 1 - MapRouteComposition.margin, accuracy: 0.001)
    }

    func testAnchorsFlipWhenDestIsSW() {
        let a = MapRouteComposition.screenAnchors(from: galpao, to: destSW)
        XCTAssertGreaterThan(a.origin.x, a.destination.x)
        XCTAssertLessThan(a.origin.y, a.destination.y)
    }

    func testRegionKeepsBothPointsInsideWithMargin() {
        let region = MapRouteComposition.region(origin: galpao, destination: destNE)
        assertInside(galpao, region: region)
        assertInside(destNE, region: region)

        // Pontos não colados no centro: ocupam boa parte do card (como mockup).
        let latSpan = region.span.latitudeDelta
        let dLat = abs(destNE.latitude - galpao.latitude)
        XCTAssertGreaterThan(latSpan, dLat * 1.15)
        XCTAssertLessThan(latSpan, dLat * 4.5)
    }

    func testRouteHasArcSamplesFromOriginToDest() {
        let points = MapRouteComposition.routeCoordinates(from: galpao, to: destNE, samples: 20)
        XCTAssertEqual(points.count, 21)
        XCTAssertEqual(points.first!.latitude, galpao.latitude, accuracy: 0.0000001)
        XCTAssertEqual(points.last!.latitude, destNE.latitude, accuracy: 0.0000001)

        // Ponto do meio desvia da reta (arco).
        let mid = points[points.count / 2]
        let straightLat = (galpao.latitude + destNE.latitude) / 2
        let straightLng = (galpao.longitude + destNE.longitude) / 2
        let deviation = hypot(mid.latitude - straightLat, mid.longitude - straightLng)
        XCTAssertGreaterThan(deviation, 0.0005)
    }

    func testGalpaoHelpersDelegateToComposition() {
        let region = GalpaoOrigem.region(containing: destNE)
        assertInside(GalpaoOrigem.coordinate, region: region)
        assertInside(destNE, region: region)
        let route = GalpaoOrigem.routeCoordinates(to: destNE)
        XCTAssertGreaterThan(route.count, 3)
    }

    private func assertInside(_ point: CLLocationCoordinate2D, region: MKCoordinateRegion) {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLng = region.center.longitude - region.span.longitudeDelta / 2
        let maxLng = region.center.longitude + region.span.longitudeDelta / 2
        XCTAssertGreaterThanOrEqual(point.latitude, minLat - 0.00001)
        XCTAssertLessThanOrEqual(point.latitude, maxLat + 0.00001)
        XCTAssertGreaterThanOrEqual(point.longitude, minLng - 0.00001)
        XCTAssertLessThanOrEqual(point.longitude, maxLng + 0.00001)
    }
}
