import CoreLocation
import XCTest
@testable import EventPro

final class MapNavigationLinksTests: XCTestCase {

    private let origin = CLLocationCoordinate2D(latitude: -23.6177585, longitude: -46.7069985)
    private let dest = CLLocationCoordinate2D(latitude: -23.5614, longitude: -46.6559)

    func testUrlTemplatesIncludeAllThreeApps() {
        let urls = MapNavigationLinks.urlTemplates(from: origin, to: dest)
        XCTAssertEqual(urls.count, 3)
        XCTAssertNotNil(urls[.appleMaps])
        XCTAssertNotNil(urls[.googleMaps])
        XCTAssertNotNil(urls[.waze])
    }

    func testAppleMapsUsesOriginAndDestination() {
        let url = MapNavigationLinks.urlTemplates(from: origin, to: dest)[.appleMaps]!
        XCTAssertTrue(url.contains("saddr=-23.6177585"))
        XCTAssertTrue(url.contains("daddr=-23.5614"))
    }

    func testGoogleMapsDirUsesOriginAndDestination() {
        let url = MapNavigationLinks.urlTemplates(from: origin, to: dest)[.googleMaps]!
        XCTAssertTrue(url.contains("origin=-23.6177585"))
        XCTAssertTrue(url.contains("destination=-23.5614"))
    }

    func testGalpaoAddressIsRealMMDPoint() {
        XCTAssertEqual(GalpaoOrigem.endereco, "Rua Doutor Mário Freire, 165")
        XCTAssertEqual(GalpaoOrigem.cidadeUf, "Morumbi, São Paulo, SP")
        XCTAssertEqual(GalpaoOrigem.latitude, -23.6177585, accuracy: 0.0000001)
        XCTAssertEqual(GalpaoOrigem.longitude, -46.7069985, accuracy: 0.0000001)
    }

    func testWazeNavigatesToDestination() {
        let url = MapNavigationLinks.urlTemplates(from: origin, to: dest)[.waze]!
        XCTAssertTrue(url.contains("ll=-23.5614,-46.6559"))
        XCTAssertTrue(url.contains("navigate=yes"))
    }

    func testGalpaoRouteStartsAndEndsAtEndpoints() {
        let points = GalpaoOrigem.routeCoordinates(to: dest)
        XCTAssertGreaterThan(points.count, 8)
        XCTAssertEqual(points.first!.latitude, GalpaoOrigem.latitude, accuracy: 0.00001)
        XCTAssertEqual(points.last!.latitude, dest.latitude, accuracy: 0.00001)
    }

    func testGalpaoRegionContainsBothPoints() {
        let region = GalpaoOrigem.region(containing: dest)
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLng = region.center.longitude - region.span.longitudeDelta / 2
        let maxLng = region.center.longitude + region.span.longitudeDelta / 2
        XCTAssertTrue(minLat <= GalpaoOrigem.latitude && GalpaoOrigem.latitude <= maxLat)
        XCTAssertTrue(minLat <= dest.latitude && dest.latitude <= maxLat)
        XCTAssertTrue(minLng <= GalpaoOrigem.longitude && GalpaoOrigem.longitude <= maxLng)
        XCTAssertTrue(minLng <= dest.longitude && dest.longitude <= maxLng)
    }
}
