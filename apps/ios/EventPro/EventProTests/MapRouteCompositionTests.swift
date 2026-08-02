import CoreLocation
import MapKit
import XCTest
@testable import EventPro

final class MapRouteCompositionTests: XCTestCase {

    private let galpao = CLLocationCoordinate2D(latitude: -23.6177585, longitude: -46.7069985)
    private let rosewood = CLLocationCoordinate2D(latitude: -23.5614, longitude: -46.6559)
    private let allianz = CLLocationCoordinate2D(latitude: -23.5275, longitude: -46.6785)
    private let ibirapuera = CLLocationCoordinate2D(latitude: -23.5874, longitude: -46.6576)

    func testDifferentDestinationsProduceDifferentVariants() {
        let a = MapRouteComposition.variantIndex(for: rosewood)
        let b = MapRouteComposition.variantIndex(for: allianz)
        let c = MapRouteComposition.variantIndex(for: ibirapuera)
        // Pelo menos dois dos três destinos típicos devem divergir.
        let unique = Set([a, b, c])
        XCTAssertGreaterThanOrEqual(unique.count, 2)
    }

    func testRouteShapesDifferByDestination() {
        let r1 = MapRouteComposition.routeCoordinates(from: galpao, to: rosewood)
        let r2 = MapRouteComposition.routeCoordinates(from: galpao, to: allianz)
        XCTAssertEqual(r1.first!.latitude, galpao.latitude, accuracy: 0.0000001)
        XCTAssertEqual(r2.first!.latitude, galpao.latitude, accuracy: 0.0000001)
        XCTAssertEqual(r1.last!.latitude, rosewood.latitude, accuracy: 0.0000001)
        XCTAssertEqual(r2.last!.latitude, allianz.latitude, accuracy: 0.0000001)

        // Ponto médio das curvas não coincide (variação natural).
        let m1 = r1[r1.count / 2]
        let m2 = r2[r2.count / 2]
        let sameMid = abs(m1.latitude - m2.latitude) < 0.0003
            && abs(m1.longitude - m2.longitude) < 0.0003
        XCTAssertFalse(sameMid, "curvas de destinos diferentes não devem coincidir no meio")
    }

    func testRouteHasVisibleArcNotStraightLine() {
        let points = MapRouteComposition.routeCoordinates(from: galpao, to: rosewood)
        let mid = points[points.count / 2]
        let straightLat = (galpao.latitude + rosewood.latitude) / 2
        let straightLng = (galpao.longitude + rosewood.longitude) / 2
        let deviation = hypot(mid.latitude - straightLat, mid.longitude - straightLng)
        XCTAssertGreaterThan(deviation, 0.0004)
    }

    func testDistanceKmIsPositiveAndRounded() {
        let km = MapRouteComposition.displayKilometers(from: galpao, to: rosewood)
        XCTAssertGreaterThanOrEqual(km, 1)
        // Morumbi → Rosewood: ordem de ~8–12 km
        XCTAssertLessThan(km, 40)
    }

    func testRegionContainsBothPoints() {
        let region = MapRouteComposition.region(origin: galpao, destination: rosewood)
        assertInside(galpao, region: region)
        assertInside(rosewood, region: region)
    }

    func testRegionsDifferByDestination() {
        let r1 = MapRouteComposition.region(origin: galpao, destination: rosewood)
        let r2 = MapRouteComposition.region(origin: galpao, destination: allianz)
        let sameCenter = abs(r1.center.latitude - r2.center.latitude) < 0.0002
            && abs(r1.center.longitude - r2.center.longitude) < 0.0002
        XCTAssertFalse(sameCenter, "enquadramentos de destinos diferentes devem divergir")
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
