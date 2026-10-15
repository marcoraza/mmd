import SwiftUI

/// Conferência RFID: tags lidas contra os seriais alocados ao Evento.
struct ConferenciaRfidView: View {

    let evento: Project

    @EnvironmentObject private var apiClient: APIClient
    @EnvironmentObject private var rfid: RFIDManager

    var body: some View {
        ConferenciaContent(evento: evento, apiClient: apiClient, rfidManager: rfid)
    }
}

@MainActor
private struct ConferenciaContent: View {

    @StateObject private var viewModel: ConferenciaViewModel
    @EnvironmentObject private var rfid: RFIDManager

    init(evento: Project, apiClient: APIClient, rfidManager: RFIDManager) {
        _viewModel = StateObject(
            wrappedValue: ConferenciaViewModel(
                evento: evento,
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
                    Picker("Contexto", selection: $viewModel.contexto) {
                        ForEach(ConferenciaContexto.allCases) { contexto in
                            Text(contexto.displayName).tag(contexto)
                        }
                    }
                    .pickerStyle(.segmented)

                    ScanControls()

                    Button {
                        Task { await viewModel.conferir() }
                    } label: {
                        if viewModel.isConferindo {
                            ProgressView()
                        } else {
                            Text("Conferir \(rfid.tagCount) tag(s)")
                        }
                    }
                    .disabled(!viewModel.podeConferir)
                } footer: {
                    Text("A conferência não muda status: ela compara o que foi lido com o que está alocado.")
                }

                if let resultado = viewModel.resultado {
                    Section("Cobertura") {
                        ProgressView(value: resultado.resumoEfetivo.coberturaFraction) {
                            Text("\(resultado.resumoEfetivo.coberturaPct)% · \(resultado.resumoEfetivo.confirmados) de \(resultado.resumoEfetivo.esperados)")
                                .font(.headline)
                        }
                    }

                    bucket("Confirmados", resultado.confirmados, icone: "checkmark.circle.fill", cor: .green)
                    bucket("Faltantes", resultado.faltantes, icone: "questionmark.circle.fill", cor: .orange)
                    bucket("Extras", resultado.extras, icone: "plus.circle.fill", cor: .blue)

                    if !resultado.desconhecidas.isEmpty {
                        Section("Desconhecidas (\(resultado.desconhecidas.count))") {
                            ForEach(resultado.desconhecidas, id: \.self) { tag in
                                Text(tag).font(.caption.monospaced())
                            }
                            Text("Tag lida sem serial correspondente. Vincule na aba Etiquetar.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !viewModel.faltantesSemTag.isEmpty {
                        Section("Faltantes sem tag vinculada (\(viewModel.faltantesSemTag.count))") {
                            Text("Esses seriais nunca vão aparecer numa leitura: falta etiqueta RFID.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(viewModel.faltantesSemTag) { serial in
                                Text(serial.codigoInterno).font(.caption.monospaced())
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Conferência RFID")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Limpar") { viewModel.limparLeitura() }
            }
        }
    }

    @ViewBuilder
    private func bucket(
        _ titulo: String,
        _ seriais: [ConferenciaSerial],
        icone: String,
        cor: Color
    ) -> some View {
        Section("\(titulo) (\(seriais.count))") {
            if seriais.isEmpty {
                Text("Nenhum.").foregroundStyle(.secondary).font(.caption)
            }
            ForEach(seriais) { serial in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icone).foregroundStyle(cor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(serial.codigoInterno).font(.body.monospaced())
                        if let nome = serial.itemNome {
                            Text(nome).font(.caption).foregroundStyle(.secondary)
                        }
                        if serial.semTagVinculada {
                            Text("sem tag vinculada")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
    }
}
