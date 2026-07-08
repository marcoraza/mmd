import XCTest
@testable import MMD_Estoque

@MainActor
final class TourControllerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AppConfig.shared.resetTours()
    }

    override func tearDown() {
        AppConfig.shared.resetTours()
        super.tearDown()
    }

    // MARK: - Start

    func testStartActivatesFirstStepAndRequestsTab() {
        let controller = TourController()
        XCTAssertFalse(controller.isActive)

        controller.start(Tour(id: .orientacao, steps: [
            info(.heroCard, tab: .inicio),
            info(.kpiCard, tab: .eventos),
        ]))

        XCTAssertTrue(controller.isActive)
        XCTAssertEqual(controller.stepNumber, 1)
        XCTAssertEqual(controller.stepCount, 2)
        XCTAssertEqual(controller.currentStep?.target, .heroCard)
        XCTAssertEqual(controller.requestedTab, .inicio)
    }

    func testStartWithEmptyTourStaysInactive() {
        let controller = TourController()
        controller.start(Tour(id: .orientacao, steps: []))
        XCTAssertFalse(controller.isActive)
    }

    // MARK: - Advancing

    func testNextAdvancesAndUpdatesRequestedTab() {
        let controller = TourController()
        controller.start(Tour(id: .orientacao, steps: [
            info(.heroCard, tab: .inicio),
            info(.kpiCard, tab: .eventos),
        ]))

        controller.next()

        XCTAssertEqual(controller.stepNumber, 2)
        XCTAssertEqual(controller.currentStep?.target, .kpiCard)
        XCTAssertEqual(controller.requestedTab, .eventos)
    }

    func testNextPastLastFinishesAndMarksDone() {
        let controller = TourController()
        controller.start(Tour(id: .checkout, steps: [info(.packingHero)]))
        XCTAssertTrue(controller.isActive)

        controller.next()

        XCTAssertFalse(controller.isActive)
        XCTAssertNil(controller.requestedTab)
        XCTAssertTrue(AppConfig.shared.isTourDone(.checkout))
    }

    // MARK: - Skip

    func testSkipFinishesAndMarksDone() {
        let controller = TourController()
        controller.start(Tour(id: .orientacao, steps: [info(.heroCard), info(.kpiCard)]))

        controller.skip()

        XCTAssertFalse(controller.isActive)
        XCTAssertTrue(AppConfig.shared.isTourDone(.orientacao))
    }

    // MARK: - Action gating

    func testNotifyActionAdvancesOnMatchingTarget() {
        let controller = TourController()
        controller.start(Tour(id: .checkout, steps: [
            action(.openCheckout),
            info(.checkoutScan),
        ]))
        XCTAssertEqual(controller.stepNumber, 1)

        controller.notifyAction(.openCheckout)

        XCTAssertEqual(controller.stepNumber, 2)
        XCTAssertEqual(controller.currentStep?.target, .checkoutScan)
    }

    func testNotifyActionIgnoresWrongTarget() {
        let controller = TourController()
        controller.start(Tour(id: .checkout, steps: [
            action(.openCheckout),
            info(.checkoutScan),
        ]))

        controller.notifyAction(.checkoutScan)

        XCTAssertEqual(controller.stepNumber, 1)
    }

    func testNotifyActionIgnoredOnInfoStep() {
        let controller = TourController()
        controller.start(Tour(id: .orientacao, steps: [info(.heroCard), info(.kpiCard)]))

        controller.notifyAction(.heroCard)

        XCTAssertEqual(controller.stepNumber, 1)
    }

    // MARK: - Real definitions sanity

    func testShippedToursAreNonEmpty() {
        XCTAssertFalse(TourDefinitions.orientacao.steps.isEmpty)
        XCTAssertFalse(TourDefinitions.checkout.steps.isEmpty)
        XCTAssertEqual(TourDefinitions.tour(for: .orientacao).id, .orientacao)
        XCTAssertEqual(TourDefinitions.tour(for: .checkout).id, .checkout)
    }

    // MARK: - Helpers

    private func info(_ target: TourTarget?, tab: LiquidTab? = nil) -> TourStep {
        TourStep(target: target, tab: tab, title: "t", body: "b",
                 kind: .info, advance: .tapNext, actionHint: nil)
    }

    private func action(_ target: TourTarget) -> TourStep {
        TourStep(target: target, tab: nil, title: "t", body: "b",
                 kind: .action, advance: .onAction(target), actionHint: "h")
    }
}
