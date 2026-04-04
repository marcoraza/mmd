import SwiftUI

@main
struct MMDEstoqueApp: App {

    @StateObject private var rfidManager = RFIDManager(useMock: AppConfig.shared.useMockRFID)

    @StateObject private var apiClient = APIClient()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(rfidManager)
                .environmentObject(apiClient)
        }
    }
}
