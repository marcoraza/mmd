import SwiftUI

/// Etiquetar: ler uma tag e vincular ao serial certo.
struct VincularTagView: View {

    @EnvironmentObject private var apiClient: APIClient
    @EnvironmentObject private var rfid: RFIDManager

    var body: some View {
        VincularTagContent(apiClient: apiClient, rfidManager: rfid)
    }
}

@MainActor
private struct VincularTagContent: View {

    @StateObject private var viewModel: VincularTagViewModel
    @EnvironmentObject private var rfid: RFIDManager

    init(apiClient: APIClient, rfidManager: RFIDManager) {
        _viewModel = StateObject(
            wrappedValue: VincularTagViewModel(apiClient: apiClient, rfidManager: rfidManager)
        )
    }

    var body: some View {
        List {
            if let error = viewModel.error {
                ErrorBanner(message: error) { viewModel.error = nil }
            }
            if let sucesso = viewModel.sucesso {
                Label(sucesso, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.footnote)
            }

            Section {
                ReaderStatusBar()
                    .listRowInsets(EdgeInsets())
                ScanControls()

                if let tag = viewModel.tagLida {
                    LabeledContent("Última tag lida") {
                        Text(tag).font(.caption.monospaced())
                    }
                } else {
                    Text("Passe a etiqueta no leitor.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Tag")
            } footer: {
                Text("A tag oferecida é a última lida por ordem de chegada, não a primeira em ordem alfabética.")
            }

            Section("Equipamento") {
                TextField("Código, nome, marca ou modelo", text: $viewModel.termo)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await viewModel.buscar() } }

                Toggle("Somente sem tag", isOn: $viewModel.somenteSemTag)

                Button {
                    Task { await viewModel.buscar() }
                } label: {
                    if viewModel.isBuscando {
                        ProgressView()
                    } else {
                        Text("Buscar")
                    }
                }
                .disabled(viewModel.isBuscando)
            }

            if !viewModel.resultados.isEmpty {
                Section("Resultados (\(viewModel.resultados.count) de \(viewModel.total))") {
                    ForEach(viewModel.resultados) { serial in
                        Button {
                            viewModel.selecionado = serial
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(serial.codigoInterno).font(.body.monospaced())
                                    if let nome = serial.itemNome {
                                        Text(nome).font(.caption).foregroundStyle(.secondary)
                                    }
                                    if let atual = serial.tagRfid {
                                        Text("já tem tag: \(atual)")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                if viewModel.selecionado?.serialId == serial.serialId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.hasMore {
                        Button("Carregar mais") {
                            Task { await viewModel.carregarMais() }
                        }
                    }
                }
            }

            Section {
                Button {
                    Task { await viewModel.vincular() }
                } label: {
                    if viewModel.isVinculando {
                        ProgressView()
                    } else {
                        Text("Vincular tag ao equipamento")
                    }
                }
                .disabled(!viewModel.podeVincular)
            } footer: {
                Text("O endpoint de vínculo ainda não está no contrato congelado (gap 4.2 da auditoria). Até ele existir, a gravação falha com mensagem explicando o que falta — o app não escreve direto no banco.")
            }
        }
        .navigationTitle("Etiquetar")
    }
}
