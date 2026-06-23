import SwiftUI

// MARK: - ReceberFlow
//
// Trilha Receber: projeto em campo -> retorno (validacao do Scan). Lista os
// projetos em campo e avanca direto pra validacao de retorno, onde o scan
// confere o lote que volta e marca defeitos.
//
// A validacao (LiquidReturnValidationView) e do dominio Scan; aqui so a
// referenciamos por nome no destino de navegacao.

struct ReceberFlow: View {

    @State private var path: [ReceberStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            LiquidProjectsListView(filter: .emCampo) { project in
                path.append(.retorno(project))
            }
            .navigationDestination(for: ReceberStep.self) { step in
                switch step {
                case .retorno(let project):
                    LiquidReturnValidationView(project: project)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - ReceberStep

private enum ReceberStep: Hashable {
    case retorno(Project)
}
