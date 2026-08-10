import SwiftUI

@main
struct EventProApp: App {

    @StateObject private var auth: AuthState
    @StateObject private var api: APIClient

    init() {
        let auth = AuthState()
        _auth = StateObject(wrappedValue: auth)
        _api = StateObject(wrappedValue: APIClient(authState: auth))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(api)
                .preferredColorScheme(.light)
        }
    }
}

/// Estado de sessao observavel sobre o AuthSessionStore (actor).
@MainActor
final class AuthState: ObservableObject {
    enum State: Equatable {
        case restoring
        case signedOut
        case signedIn(email: String?)
    }

    @Published private(set) var state: State = .restoring

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    var email: String? {
        guard case .signedIn(let email) = state else { return nil }
        return email
    }

    private let store: AuthSessionStore

    init(
        store: AuthSessionStore = .shared,
        restoreOnInit: Bool = true
    ) {
        self.store = store
        if restoreOnInit {
            Task { await restore() }
        }
    }

    func restore() async {
        guard await store.hasSession else {
            state = .signedOut
            return
        }
        state = .signedIn(email: await store.sessionEmail)
    }

    func signIn(identifier: String, password: String) async throws {
        try await store.signIn(identifier: identifier, password: password)
        await restore()
    }

    func signOut() {
        Task { await invalidateSession() }
    }

    func invalidateSession() async {
        await store.signOut()
        state = .signedOut
    }

    func validAccessToken() async throws -> String {
        do {
            return try await store.validAccessToken()
        } catch AuthError.notAuthenticated, AuthError.sessionExpired, AuthError.invalidCredentials {
            await invalidateSession()
            throw AuthError.sessionExpired
        } catch {
            throw error
        }
    }

    func refreshedAccessToken() async throws -> String {
        do {
            return try await store.refreshedAccessToken()
        } catch AuthError.notAuthenticated, AuthError.sessionExpired, AuthError.invalidCredentials {
            await invalidateSession()
            throw AuthError.sessionExpired
        } catch {
            throw error
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var auth: AuthState

    var body: some View {
        ZStack {
            EP.paper.ignoresSafeArea()
            switch auth.state {
            case .restoring:
                ProgressView()
                    .tint(EP.ink)
                    .accessibilityLabel("Restaurando sessão")
            case .signedIn:
                HomeView()
                    .transition(.opacity)
            case .signedOut:
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(EP.ease, value: auth.state)
    }
}
