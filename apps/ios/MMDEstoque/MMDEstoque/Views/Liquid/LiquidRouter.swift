import SwiftUI

// MARK: - LiquidRouter
//
// Navegacao centralizada num unico NavigationStack. A raiz e dona do path; as
// telas (de qualquer profundidade) empurram rotas via @EnvironmentObject, sem
// stacks aninhados nem threading de closures.

final class LiquidRouter: ObservableObject {

    @Published var path = NavigationPath()
    @Published var tab: LiquidTab = .inicio

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
