import SwiftUI

@main
struct MMDEstoqueApp: App {

    @StateObject private var rfidManager = RFIDManager(useMock: AppConfig.shared.useMockRFID)

    @StateObject private var apiClient = APIClient()

    @StateObject private var router = LiquidRouter()

    @StateObject private var tourController = TourController()

    var body: some Scene {
        WindowGroup {
            LiquidRoot()
                .environmentObject(rfidManager)
                .environmentObject(apiClient)
                .environmentObject(router)
                .environmentObject(tourController)
        }
    }
}
