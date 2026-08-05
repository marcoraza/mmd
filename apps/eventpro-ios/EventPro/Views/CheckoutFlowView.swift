import SwiftUI

/// Check-out: conferir o packing por scan e disparar a saída.
struct CheckoutFlowView: View {

    let evento: Project

    @EnvironmentObject private var apiClient: APIClient
    @EnvironmentObject private var rfid: RFIDManager

    var body: some View {
        CheckoutFlowContent(evento: evento, apiClient: apiClient, rfidManager: rfid)
    }
}

@MainActor
private struct CheckoutFlowContent: View {

    @StateObject private var viewModel: CheckoutViewModel
    @State private var carregou = false
    @State private var mostrandoQR = false
    @State private var qrAtivo = false
    @State private var mostrandoOverride = false
    @State private var motivoOverride = ""

    init(evento: Project, apiClient: APIClient, rfidManager: RFIDManager) {
        _viewModel = StateObject(
            wrappedValue: CheckoutViewModel(
                project: evento,
                apiClient: apiClient,
                rfidManager: rfidManager
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ReaderStatusBar()

            List {
                if let error = viewModel.error {
                    ErrorBanner(message: error) { viewModel.error = nil }
                }

                Section {
                    Picker("Método", selection: $viewModel.scanMethod) {
                        ForEach(MetodoScan.allCases) { metodo in
                            Text(metodo.displayName).tag(metodo)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.scanMethod == .rfid {
                        ScanControls()
                    } else if viewModel.scanMethod == .qrcode {
                        Button("Abrir câmera") {
                            qrAtivo = true
                            mostrandoQR = true
                        }
                    }
                }

                Section("Conferência (\(viewModel.totalScanned)/\(viewModel.totalExpected))") {
                    ForEach(viewModel.packingListItems) { linha in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(linha.displayName)
                                Text("\(viewModel.matchedCounts[linha.id] ?? 0) de \(linha.quantidade)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            statusIcon(for: viewModel.validationState(for: linha))
                        }
                    }
                }

                if !viewModel.extraItems.isEmpty {
                    Section("Fora do packing (\(viewModel.extraItems.count))") {
                        ForEach(viewModel.extraItems) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.codigoInterno).font(.body.monospaced())
                                Text(item.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !viewModel.unresolvedTags.isEmpty {
                    Section("Tags não reconhecidas (\(viewModel.unresolvedTags.count))") {
                        ForEach(viewModel.unresolvedTags, id: \.self) { tag in
                            Text(tag).font(.caption.monospaced())
                        }
                    }
                }

                if let resultado = viewModel.resultado {
                    Section("Resultado") {
                        Text("\(resultado.count) serial(is) em campo.")
                        ForEach(resultado.seriais, id: \.serialId) { serial in
                            Text(serial.codigoInterno).font(.caption.monospaced())
                        }
                    }
                }
            }

            footer
        }
        .navigationTitle("Check-out")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !carregou else { return }
            carregou = true
            await viewModel.loadPackingList()
        }
        .sheet(isPresented: $mostrandoQR) {
            NavigationStack {
                QRScannerContainer(isActive: $qrAtivo) { code in
                    viewModel.processQRCode(code)
                }
                .navigationTitle("Ler QR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fechar") {
                            qrAtivo = false
                            mostrandoQR = false
                        }
                    }
                }
            }
        }
        .alert("Check-out com pendência", isPresented: $mostrandoOverride) {
            TextField("Motivo (mínimo 10 caracteres)", text: $motivoOverride)
            Button("Cancelar", role: .cancel) {}
            Button("Confirmar") {
                Task { await viewModel.finalizeCheckout(overrideReason: motivoOverride) }
            }
            .disabled(motivoOverride.trimmingCharacters(in: .whitespacesAndNewlines).count < 10)
        } message: {
            Text("O servidor só libera com usuário admin e motivo de 10 caracteres ou mais.")
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 8) {
            if viewModel.checkoutComplete {
                Label("Check-out registrado.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    Task { await viewModel.finalizeCheckout() }
                } label: {
                    if viewModel.isProcessingCheckout {
                        ProgressView()
                    } else {
                        Text("Finalizar check-out")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isProcessingCheckout)

                Button("Finalizar com override") {
                    motivoOverride = ""
                    mostrandoOverride = true
                }
                .font(.footnote)
            }
        }
        .padding()
        .background(.thinMaterial)
    }

    @ViewBuilder
    private func statusIcon(for state: PackingItemValidation) -> some View {
        switch state {
        case .pending:
            Image(systemName: "circle").foregroundStyle(.secondary)
        case .complete:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .over:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
        }
    }
}
