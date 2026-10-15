import SwiftUI

@main
struct EventProApp: App {

    @StateObject private var authService: AuthService
    @StateObject private var apiClient: APIClient
    @StateObject private var rfidManager: RFIDManager

    init() {
        // O APIClient pega o token do AuthService antes de cada requisição, então
        // os dois nascem juntos aqui, não em `@StateObject` independentes.
        let auth = AuthService()
        _authService = StateObject(wrappedValue: auth)
        _apiClient = StateObject(wrappedValue: APIClient(authService: auth))
        _rfidManager = StateObject(wrappedValue: RFIDManager(useMock: AppConfig.shared.useMockRFID))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(apiClient)
                .environmentObject(rfidManager)
        }
    }
}
