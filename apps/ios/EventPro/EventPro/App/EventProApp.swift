import SwiftUI

@main
struct EventProApp: App {

    @StateObject private var auth = AuthState()
    @StateObject private var api = APIClient()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(api)
                .preferredColorScheme(.dark)
        }
    }
}

/// Estado de sessao observavel sobre o AuthSessionStore (actor).
@MainActor
final class AuthState: ObservableObject {
    @Published var isSignedIn = false
    @Published var email: String?

    private let store = AuthSessionStore.shared

    init() {
        Task { await refresh() }
    }

    func refresh() async {
        isSignedIn = await store.hasSession
        email = await store.sessionEmail
    }

    func signIn(identifier: String, password: String) async throws {
        try await store.signIn(identifier: identifier, password: password)
        await refresh()
    }

    func signOut() {
        Task {
            await store.signOut()
            await refresh()
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var auth: AuthState

    var body: some View {
        ZStack {
            EP.bg0.ignoresSafeArea()
            if auth.isSignedIn {
                HomeView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(EP.ease, value: auth.isSignedIn)
    }
}
