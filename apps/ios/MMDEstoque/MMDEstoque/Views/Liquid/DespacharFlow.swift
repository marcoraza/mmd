import SwiftUI

// MARK: - DespacharFlow
//
// Trilha Despachar: projeto a sair -> packing -> check-out (validacao do Scan).
// Lista os projetos confirmados, abre o packing pra conferencia e avanca pra
// validacao de check-out, onde o scan registra a saida pra campo (EM_CAMPO).
//
// A validacao (LiquidCheckoutValidationView) e do dominio Scan; aqui so a
// referenciamos por nome no destino de navegacao.

struct DespacharFlow: View {

    @State private var path: [DespacharStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            LiquidProjectsListView(filter: .aSair) { project in
                path.append(.packing(project))
            }
            .navigationDestination(for: DespacharStep.self) { step in
                switch step {
                case .packing(let project):
                    LiquidPackingListView(project: project) {
                        path.append(.checkout(project))
                    }
                case .checkout(let project):
                    LiquidCheckoutValidationView(project: project)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - DespacharStep

private enum DespacharStep: Hashable {
    case packing(Project)
    case checkout(Project)
}
