import SwiftUI

/// Home: Eventos abertos, com prontidão vinda do endpoint de resumo.
///
/// Padrão usado em todas as telas com ViewModel: a view externa lê o
/// `@EnvironmentObject` e repassa para uma view interna cujo `init` monta o
/// `@StateObject`. `StateObject(wrappedValue:)` recebe um autoclosure avaliado
/// uma única vez, então o ViewModel não é recriado a cada `body`.
struct EventosListView: View {

    @EnvironmentObject private var apiClient: APIClient

    var body: some View {
        EventosListContent(apiClient: apiClient)
    }
}

@MainActor
private struct EventosListContent: View {

    @StateObject private var viewModel: EventosViewModel
    @State private var carregou = false

    init(apiClient: APIClient) {
        _viewModel = StateObject(wrappedValue: EventosViewModel(apiClient: apiClient))
    }

    var body: some View {
        List {
            if let error = viewModel.error {
                ErrorBanner(message: error)
            }

            if viewModel.eventos.isEmpty && !viewModel.isLoading {
                Text("Nenhum evento aberto.")
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.eventos) { evento in
                NavigationLink(value: evento) {
                    EventoRow(evento: evento, resumo: viewModel.resumo(for: evento))
                }
            }
        }
        .navigationTitle("Eventos")
        .navigationDestination(for: Project.self) { evento in
            EventoDetailView(evento: evento)
        }
        .refreshable { await recarregar() }
        .overlay {
            if viewModel.isLoading && viewModel.eventos.isEmpty {
                ProgressView()
            }
        }
        .task {
            guard !carregou else { return }
            carregou = true
            await recarregar()
        }
    }

    private func recarregar() async {
        await viewModel.load()
        for evento in viewModel.eventos {
            await viewModel.loadResumo(for: evento)
        }
    }
}

struct EventoRow: View {

    let evento: Project
    let resumo: EventoResumo?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(evento.nome)
                .font(.headline)

            HStack(spacing: 6) {
                Text(evento.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())

                if let cliente = evento.cliente {
                    Text(cliente)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let periodo = evento.periodoFormatado {
                Text(periodo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let packing = resumo?.packing {
                ProgressView(value: packing.readinessFraction) {
                    Text("Prontidão \(packing.readinessPct)% · \(packing.itensAlocados)/\(packing.itensTotal) itens")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
