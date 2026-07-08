import SwiftUI

// MARK: - LiquidReturnValidationView
//
// Camada de retorno/defeito sobre o ScanEngine. O motor le o lote que volta
// do campo e o ReturnViewModel pede a condicao de cada item: OK volta pra
// DISPONIVEL, defeito vai pra MANUTENCAO com desgaste novo e notas. A acao
// primaria "Confirmar volta" registra os retornos.
//
// Wrapper publico (contrato: LiquidReturnValidationView(project:)) repassa os
// EnvironmentObjects pro conteudo dono do @StateObject do view model.

struct LiquidReturnValidationView: View {

    let project: Project

    @EnvironmentObject private var rfid: RFIDManager
    @EnvironmentObject private var apiClient: APIClient

    var body: some View {
        LiquidReturnValidationContent(
            project: project,
            apiClient: apiClient,
            rfidManager: rfid
        )
        .environmentObject(rfid)
    }
}

// MARK: - Content

private struct LiquidReturnValidationContent: View {

    let project: Project

    @StateObject private var viewModel: ReturnViewModel

    @EnvironmentObject private var router: LiquidRouter
    @State private var showQRScanner = false

    init(project: Project, apiClient: APIClient, rfidManager: RFIDManager) {
        self.project = project
        _viewModel = StateObject(wrappedValue: ReturnViewModel(
            project: project,
            apiClient: apiClient,
            rfidManager: rfidManager
        ))
    }

    private var progress: Double {
        guard viewModel.totalItems > 0 else { return 0 }
        return Double(viewModel.scannedCount) / Double(viewModel.totalItems)
    }

    var body: some View {
        ZStack {
            TechnicalGridCanvas()

            VStack(spacing: 0) {
                returnPanel
                scanLayer
            }

            if let id = viewModel.pendingAssessmentId,
               let item = viewModel.outboundItems.first(where: { $0.id == id }) {
                LiquidConditionAssessment(
                    item: item.resolved,
                    onOK: { viewModel.markAsOK(serialId: id) },
                    onDefect: { notas, desgaste in
                        viewModel.markAsDefect(serialId: id, notas: notas, desgaste: desgaste)
                    },
                    onDismiss: { viewModel.pendingAssessmentId = nil }
                )
            }

            if viewModel.returnComplete {
                LiquidCompletionOverlay(
                    title: "Volta registrada",
                    message: returnSummary
                ) {
                    router.popToRoot()
                }
            }
        }
        .navigationTitle("Confirmar volta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.loadOutboundItems() }
        .sheet(isPresented: $showQRScanner) {
            LiquidQRScannerSheet { code in
                viewModel.processQRCode(code)
            }
        }
    }

    /// Resumo humano do retorno pro fechamento do fluxo.
    private var returnSummary: String {
        var partes = ["\(viewModel.okCount) OK"]
        if viewModel.defectCount > 0 { partes.append("\(viewModel.defectCount) com defeito") }
        if viewModel.missingCount > 0 { partes.append("\(viewModel.missingCount) não voltaram") }
        return partes.joined(separator: " · ")
    }

    /// Motivo do "Confirmar volta" travado.
    private var finalizeHint: String? {
        guard !viewModel.canFinalize else { return nil }
        if viewModel.outboundItems.isEmpty {
            return "Nenhum item em campo neste evento"
        }
        return "Escaneie o lote que voltou pra liberar a confirmação"
    }

    // MARK: - Return Panel

    private var returnPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Liquid.Space.lg) {
                summaryHeader

                if !viewModel.outboundItems.isEmpty {
                    itemList
                }
            }
            .padding(Liquid.Space.xxl)
            .padding(.bottom, Liquid.Space.md)
        }
        .frame(maxHeight: .infinity)
    }

    private var summaryHeader: some View {
        HStack(spacing: Liquid.Space.xl) {
            ReadinessGauge(
                progress: progress,
                diameter: 56,
                stroke: 5,
                caption: nil
            )

            HStack(spacing: 0) {
                countPill("\(viewModel.okCount)", label: "OK", dot: Liquid.accentGreen)
                countPill("\(viewModel.defectCount)", label: "defeito", dot: Liquid.accentRed)
                countPill("\(viewModel.missingCount)", label: "falta", dot: Liquid.accentAmber)
            }
        }
        .padding(Liquid.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelSurface(cornerRadius: Liquid.Radius.lg)
    }

    private func countPill(_ value: String, label: String, dot: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.liquidMono(18, weight: .medium))
                .foregroundStyle(Liquid.fg0)
                .contentTransition(.numericText())

            HStack(spacing: Liquid.Space.xs) {
                Circle().fill(dot).frame(width: 5, height: 5)
                Text(label)
                    .font(.liquidSans(11, weight: .medium))
                    .foregroundStyle(Liquid.fg2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var itemList: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            LiquidSectionHeader(
                title: "Itens em campo",
                trailing: "\(viewModel.outboundItems.count)"
            )

            VStack(spacing: Liquid.Space.sm) {
                ForEach(viewModel.outboundItems) { item in
                    itemRow(item)
                }
            }
        }
    }

    private func itemRow(_ item: ReturnItemState) -> some View {
        let color: Color
        let statusText: String
        switch item.result {
        case .pending:
            color = Liquid.accentAmber
            statusText = "Pendente"
        case .ok:
            color = Liquid.accentGreen
            statusText = "OK"
        case .defeito:
            color = Liquid.accentRed
            statusText = "Defeito"
        }

        return HStack(spacing: Liquid.Space.md) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: Liquid.Space.xxs) {
                Text(item.resolved.displayName)
                    .font(.liquidSans(14, weight: .medium))
                    .foregroundStyle(Liquid.fg0)
                    .lineLimit(1)
                Text(item.resolved.codigoInterno)
                    .liquidMonoData(11, color: Liquid.fg3)
            }

            Spacer(minLength: Liquid.Space.sm)

            Text(statusText)
                .font(.liquidSans(12, weight: .semibold))
                .foregroundStyle(color)

            // Reavaliar manualmente um item ja lido; buscar um que nao voltou.
            if item.isScanned {
                Button {
                    viewModel.pendingAssessmentId = item.id
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Liquid.fg2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reavaliar condição")
            } else {
                Button {
                    var serial = item.resolved.serialNumber
                    serial.item = item.resolved.equipment
                    router.push(.itemLost(serial))
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Liquid.accentAmber)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Buscar item que não voltou")
            }
        }
        .padding(.horizontal, Liquid.Space.lg)
        .padding(.vertical, Liquid.Space.md)
        .panelSurface(cornerRadius: Liquid.Radius.md)
    }

    // MARK: - Scan Layer

    private var scanLayer: some View {
        ScanEngine(
            heroUnit: "TAGS LIDAS",
            emptyHint: "Aponte o leitor pro lote que volta do campo",
            primaryAction: ScanAction(
                label: "Confirmar volta",
                isBusy: viewModel.isProcessingReturn,
                isEnabled: viewModel.canFinalize,
                disabledHint: finalizeHint
            ) {
                Task { await viewModel.finalizeReturn() }
            },
            onQRFallback: { showQRScanner = true },
            onNeedsReader: { router.push(.conectar) },
            errorMessage: viewModel.error
        )
        .frame(maxHeight: .infinity)
    }
}

// MARK: - LiquidConditionAssessment
//
// Modal de condicao: nomeia o item, OK direto, ou abre o controle de desgaste
// e notas pro defeito. Controle de desgaste interativo nativo Liquid.

private struct LiquidConditionAssessment: View {

    let item: ResolvedItem
    let onOK: () -> Void
    let onDefect: (_ notas: String, _ desgaste: Int) -> Void
    let onDismiss: () -> Void

    @State private var showingDefect = false
    @State private var notas = ""
    @State private var desgaste: Int

    init(
        item: ResolvedItem,
        onOK: @escaping () -> Void,
        onDefect: @escaping (String, Int) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.item = item
        self.onOK = onOK
        self.onDefect = onDefect
        self.onDismiss = onDismiss
        // Defeito comeca um degrau abaixo do desgaste atual.
        _desgaste = State(initialValue: max(item.serialNumber.desgaste - 1, 1))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: Liquid.Space.xl) {
                header

                if showingDefect {
                    defectFields
                    confirmDefectButton
                } else {
                    choiceButtons
                }
            }
            .padding(Liquid.Space.xxl)
            .panelSurface(cornerRadius: Liquid.Radius.lg)
            .padding(Liquid.Space.xxl)
        }
        .liquidElevatedShadow()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.xs) {
            Text("Condição do item")
                .liquidSection()
            Text(item.displayName)
                .font(.liquidSans(18, weight: .semibold))
                .foregroundStyle(Liquid.fg0)
                .lineLimit(1)
            Text(item.codigoInterno)
                .liquidMonoData(12, color: Liquid.fg3)
        }
    }

    private var choiceButtons: some View {
        HStack(spacing: Liquid.Space.md) {
            choiceButton("OK", tint: Liquid.accentGreen, filled: true) { onOK() }
            choiceButton("Com defeito", tint: Liquid.accentRed, filled: false) {
                withAnimation(Liquid.Motion.fast) { showingDefect = true }
            }
        }
    }

    private func choiceButton(
        _ label: String, tint: Color, filled: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.liquidSans(15, weight: .semibold))
                .foregroundStyle(filled ? Liquid.bg0 : tint)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background {
                    let shape = RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                    if filled {
                        shape.fill(tint)
                    } else {
                        shape.fill(Liquid.bg2)
                            .overlay(shape.strokeBorder(Liquid.hairlineStrong, lineWidth: 1))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var defectFields: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            Text("Novo desgaste")
                .liquidSection()

            LiquidWearStepper(level: $desgaste)

            Text("Notas do defeito")
                .liquidSection()

            TextField("", text: $notas, axis: .vertical)
                .font(.liquidBody)
                .foregroundStyle(Liquid.fg0)
                .lineLimit(3...6)
                .padding(Liquid.Space.md)
                .background(
                    RoundedRectangle(cornerRadius: Liquid.Radius.sm, style: .continuous)
                        .fill(Liquid.bg0.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: Liquid.Radius.sm, style: .continuous)
                                .strokeBorder(Liquid.glassBorder, lineWidth: 1)
                        )
                )
                .overlay(alignment: .topLeading) {
                    if notas.isEmpty {
                        Text("Descreva o problema")
                            .liquidBody()
                            .foregroundStyle(Liquid.fg3)
                            .padding(.horizontal, Liquid.Space.md + 4)
                            .padding(.vertical, Liquid.Space.md + 8)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var confirmDefectButton: some View {
        let enabled = !notas.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Button {
            onDefect(notas, desgaste)
        } label: {
            Text("Confirmar defeito")
                .font(.liquidSans(15, weight: .semibold))
                .foregroundStyle(enabled ? Liquid.bg0 : Liquid.fg3)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                        .fill(enabled ? Liquid.accentRed : Liquid.bg2)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - LiquidWearStepper
//
// Controle de desgaste interativo nativo Liquid (1-5). Toca o segmento pra
// setar o nivel; a cor segue o liquidWearColor.

private struct LiquidWearStepper: View {
    @Binding var level: Int

    private let total = 5

    var body: some View {
        HStack(spacing: Liquid.Space.md) {
            HStack(spacing: 4) {
                ForEach(1...total, id: \.self) { index in
                    Button {
                        withAnimation(Liquid.Motion.fast) { level = index }
                    } label: {
                        Capsule()
                            .fill(index <= level ? level.liquidWearColor : Liquid.glassBorderStrong)
                            .frame(height: 12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Desgaste \(index)")
                }
            }

            Text("\(level)/5")
                .font(.liquidMono(13, weight: .medium))
                .foregroundStyle(level.liquidWearColor)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LiquidReturnValidationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LiquidReturnValidationView(
                project: Project(
                    id: UUID(),
                    nome: "Festival de Verão",
                    cliente: "Produções XYZ",
                    status: .emCampo
                )
            )
            .environmentObject(RFIDManager(useMock: true))
            .environmentObject(APIClient())
        }
        .preferredColorScheme(.dark)
    }
}
#endif
