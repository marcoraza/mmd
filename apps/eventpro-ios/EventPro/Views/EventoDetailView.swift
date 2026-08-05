import SwiftUI

/// Detalhe do Evento: resumo, packing list e as ações de campo.
struct EventoDetailView: View {

    let evento: Project

    @EnvironmentObject private var apiClient: APIClient

    var body: some View {
        EventoDetailContent(evento: evento, apiClient: apiClient)
    }
}

@MainActor
private struct EventoDetailContent: View {

    @StateObject private var viewModel: EventoDetailViewModel
    @State private var carregou = false

    init(evento: Project, apiClient: APIClient) {
        _viewModel = StateObject(
            wrappedValue: EventoDetailViewModel(evento: evento, apiClient: apiClient)
        )
    }

    private var evento: Project { viewModel.evento }

    var body: some View {
        List {
            if let error = viewModel.error {
                Section { ErrorBanner(message: error) }
            }

            Section("Evento") {
                LabeledContent("Status", value: viewModel.status.displayName)
                if let cliente = evento.cliente {
                    LabeledContent("Cliente", value: cliente)
                }
                if let local = viewModel.resumo?.local ?? evento.local {
                    LabeledContent("Local", value: local)
                }
                if let periodo = evento.periodoFormatado {
                    LabeledContent("Período", value: periodo)
                }
            }

            if let packing = viewModel.resumo?.packing {
                Section("Prontidão") {
                    ProgressView(value: packing.readinessFraction) {
                        Text("\(packing.readinessPct)%")
                            .font(.headline)
                    }
                    LabeledContent("Linhas", value: "\(packing.linhas)")
                    LabeledContent("Itens alocados", value: "\(packing.itensAlocados) de \(packing.itensTotal)")
                }
            }

            Section("Ações de campo") {
                NavigationLink {
                    CheckoutFlowView(evento: evento)
                } label: {
                    Label("Check-out", systemImage: "shippingbox")
                }
                .disabled(!viewModel.podeFazerCheckout)

                NavigationLink {
                    ReturnFlowView(evento: evento)
                } label: {
                    Label("Retorno", systemImage: "arrow.uturn.left")
                }
                .disabled(!viewModel.podeFazerRetorno)

                NavigationLink {
                    ConferenciaRfidView(evento: evento)
                } label: {
                    Label("Conferência RFID", systemImage: "dot.radiowaves.left.and.right")
                }
            }

            Section("Packing list (\(viewModel.packing.count) linhas)") {
                if viewModel.packing.isEmpty && !viewModel.isLoading {
                    Text("Sem linhas de packing.")
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.packing) { linha in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(linha.displayName)
                        Text("Qtd \(linha.quantidade) · \(linha.designados.count) serial(is) alocado(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(evento.nome)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .task {
            guard !carregou else { return }
            carregou = true
            await viewModel.load()
        }
    }
}
