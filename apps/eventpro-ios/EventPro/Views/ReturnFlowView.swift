import SwiftUI

/// Retorno: conferir o que voltou, marcar condição e registrar.
///
/// Os três desfechos do contrato aparecem na tela: OK, PROBLEMA e NAO_VOLTOU.
/// Item não conferido **não some** — na finalização vira NAO_VOLTOU, com
/// confirmação explícita (divergência D1).
struct ReturnFlowView: View {

    let evento: Project

    @EnvironmentObject private var apiClient: APIClient
    @EnvironmentObject private var rfid: RFIDManager

    var body: some View {
        ReturnFlowContent(evento: evento, apiClient: apiClient, rfidManager: rfid)
    }
}

@MainActor
private struct ReturnFlowContent: View {

    @StateObject private var viewModel: ReturnViewModel
    @State private var carregou = false
    @State private var mostrandoQR = false
    @State private var qrAtivo = false
    @State private var confirmandoPendentes = false

    // Modal de avaliação
    @State private var observacao = ""
    @State private var desgaste = 3

    init(evento: Project, apiClient: APIClient, rfidManager: RFIDManager) {
        _viewModel = StateObject(
            wrappedValue: ReturnViewModel(
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

                Section("Placar") {
                    LabeledContent("OK", value: "\(viewModel.okCount)")
                    LabeledContent("Problema", value: "\(viewModel.problemaCount)")
                    LabeledContent("Não voltou", value: "\(viewModel.naoVoltouCount)")
                    LabeledContent("Não conferido", value: "\(viewModel.pendenteCount)")
                }

                Section("Unidades em campo (\(viewModel.totalItems))") {
                    if viewModel.outboundItems.isEmpty && !viewModel.isLoading {
                        Text("Nenhuma unidade própria em campo neste evento.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.outboundItems) { item in
                        ReturnItemRow(item: item) { novo in
                            aplicar(novo, para: item)
                        }
                    }
                }

                if let resultado = viewModel.resultado {
                    Section("Resultado") {
                        Text("\(resultado.count) unidade(s) processada(s).")
                        ForEach(resultado.seriais, id: \.serialId) { serial in
                            HStack {
                                Text(serial.codigoInterno).font(.caption.monospaced())
                                Spacer()
                                Text(serial.novoStatus).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            footer
        }
        .navigationTitle("Retorno")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !carregou else { return }
            carregou = true
            await viewModel.loadOutboundItems()
        }
        .sheet(item: pendingBinding) { item in
            NavigationStack {
                AvaliacaoView(
                    item: item,
                    observacao: $observacao,
                    desgaste: $desgaste,
                    onOK: {
                        viewModel.markAsOK(serialId: item.id)
                        limparModal()
                    },
                    onProblema: {
                        if viewModel.markAsProblema(
                            serialId: item.id,
                            observacao: observacao,
                            desgaste: desgaste
                        ) {
                            limparModal()
                        }
                    },
                    onNaoVoltou: {
                        viewModel.markAsNaoVoltou(serialId: item.id)
                        limparModal()
                    },
                    onCancelar: { limparModal() }
                )
            }
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
        .alert("Finalizar com pendências?", isPresented: $confirmandoPendentes) {
            Button("Cancelar", role: .cancel) {}
            Button("Confirmar", role: .destructive) {
                Task { await viewModel.finalizeReturn(confirmarPendentesComoNaoVoltou: true) }
            }
        } message: {
            Text(
                "\(viewModel.pendenteCount) unidade(s) não foram conferidas e serão registradas como NÃO VOLTOU. Isso abre pendência e o Evento não fecha até a resolução."
            )
        }
    }

    /// O modal de avaliação abre a partir do id publicado pelo ViewModel.
    private var pendingBinding: Binding<ReturnItemState?> {
        Binding(
            get: {
                guard let id = viewModel.pendingAssessmentId else { return nil }
                return viewModel.outboundItems.first { $0.id == id }
            },
            set: { novo in
                if novo == nil { viewModel.pendingAssessmentId = nil }
            }
        )
    }

    private func aplicar(_ resultado: ReturnResult, para item: ReturnItemState) {
        switch resultado {
        case .ok:
            viewModel.markAsOK(serialId: item.id)
        case .naoVoltou:
            viewModel.markAsNaoVoltou(serialId: item.id)
        case .pendente:
            viewModel.resetItem(serialId: item.id)
        case .problema:
            observacao = ""
            desgaste = item.resolved.serialNumber.desgaste
            viewModel.pendingAssessmentId = item.id
        }
    }

    private func limparModal() {
        observacao = ""
        desgaste = 3
        viewModel.pendingAssessmentId = nil
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 8) {
            if viewModel.returnComplete {
                Label("Retorno registrado.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    if viewModel.requerConfirmacaoDePendentes {
                        confirmandoPendentes = true
                    } else {
                        Task { await viewModel.finalizeReturn() }
                    }
                } label: {
                    if viewModel.isProcessingReturn {
                        ProgressView()
                    } else {
                        Text("Finalizar retorno")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canFinalize)

                Text("A API exige cobertura total: todas as \(viewModel.totalItems) unidades vão no mesmo envio.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(.thinMaterial)
    }
}

// MARK: - Linha

private struct ReturnItemRow: View {

    let item: ReturnItemState
    let onChange: (ReturnResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.resolved.codigoInterno).font(.body.monospaced())
            Text(item.resolved.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                botao("OK", ativo: item.result == .ok) { onChange(.ok) }
                botao("Problema", ativo: isProblema) {
                    onChange(.problema(observacao: "", desgaste: item.resolved.serialNumber.desgaste))
                }
                botao("Não voltou", ativo: item.result == .naoVoltou) { onChange(.naoVoltou) }
                if item.result != .pendente {
                    Button("Limpar") { onChange(.pendente) }
                        .font(.caption2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var isProblema: Bool {
        if case .problema = item.result { return true }
        return false
    }

    @ViewBuilder
    private func botao(_ titulo: String, ativo: Bool, acao: @escaping () -> Void) -> some View {
        Button(titulo, action: acao)
            .font(.caption)
            .buttonStyle(.bordered)
            .tint(ativo ? .accentColor : .secondary)
    }
}

// MARK: - Avaliação

private struct AvaliacaoView: View {

    let item: ReturnItemState
    @Binding var observacao: String
    @Binding var desgaste: Int

    let onOK: () -> Void
    let onProblema: () -> Void
    let onNaoVoltou: () -> Void
    let onCancelar: () -> Void

    var body: some View {
        Form {
            Section(item.resolved.codigoInterno) {
                Text(item.resolved.displayName)
                Text(item.resolved.condicaoLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Desgaste") {
                Picker("Desgaste", selection: $desgaste) {
                    ForEach(1...5, id: \.self) { valor in
                        Text("\(valor)").tag(valor)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                TextField("Observação (obrigatória em problema)", text: $observacao, axis: .vertical)
                    .lineLimit(2...4)
            } footer: {
                Text("Mínimo de 3 caracteres. O servidor trunca em 240.")
            }

            Section {
                Button("Voltou OK", action: onOK)
                Button("Voltou com problema", action: onProblema)
                    .disabled(!ReturnViewModel.isObservacaoValida(observacao))
                Button("Não voltou", role: .destructive, action: onNaoVoltou)
            }
        }
        .navigationTitle("Conferir unidade")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar", action: onCancelar)
            }
        }
    }
}
