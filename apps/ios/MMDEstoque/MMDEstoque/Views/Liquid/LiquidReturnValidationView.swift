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
            CausticBackground(intensity: .work).ignoresSafeArea()

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
        GlassCard(strong: true) {
            HStack(spacing: Liquid.Space.xl) {
                ReadinessGauge(
                    progress: progress,
                    diameter: Liquid.Ring.sizeMd,
                    stroke: Liquid.Ring.strokeMd,
                    caption: nil
                )

                HStack(spacing: Liquid.Space.lg) {
                    countPill("\(viewModel.okCount)", label: "OK", color: Liquid.accentGreen)
                    countPill("\(viewModel.defectCount)", label: "Defeito", color: Liquid.accentRed)
                    countPill("\(viewModel.missingCount)", label: "Falta", color: Liquid.accentAmber)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func countPill(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: Liquid.Space.xxs) {
            Text(value)
                .font(.liquidMono(22, weight: .medium))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .liquidLabel(color)
        }
    }

    private var itemList: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            Text("Itens em campo")
                .liquidLabel()

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
                .liquidGlow(color, radius: 5, opacity: 0.7)

            VStack(alignment: .leading, spacing: Liquid.Space.xxs) {
                Text(item.resolved.displayName)
                    .liquidBody()
                    .foregroundStyle(Liquid.fg0)
                    .lineLimit(1)
                Text(item.resolved.codigoInterno)
                    .liquidMonoData(11, color: Liquid.fg2)
            }

            Spacer(minLength: Liquid.Space.sm)

            Text(statusText)
                .liquidLabel(color)

            // Reavaliar manualmente um item ja lido.
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
            }
        }
        .padding(.horizontal, Liquid.Space.lg)
        .padding(.vertical, Liquid.Space.md)
        .glassSurface(cornerRadius: Liquid.Radius.md, strong: true)
    }

    // MARK: - Scan Layer

    private var scanLayer: some View {
        ScanEngine(
            heroUnit: "TAGS LIDAS",
            emptyHint: "Aponte o leitor pro lote que volta do campo",
            primaryAction: ScanAction(
                label: "Confirmar volta",
                isBusy: viewModel.isProcessingReturn,
                isEnabled: viewModel.canFinalize
            ) {
                Task { await viewModel.finalizeReturn() }
            },
            onQRFallback: { showQRScanner = true },
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

            GlassCard(strong: true) {
                VStack(alignment: .leading, spacing: Liquid.Space.xl) {
                    header

                    if showingDefect {
                        defectFields
                        confirmDefectButton
                    } else {
                        choiceButtons
                    }
                }
            }
            .padding(Liquid.Space.xxl)
        }
        .liquidElevatedShadow()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.xs) {
            Text("Condição do item")
                .liquidLabel(Liquid.accentCyan)
            Text(item.displayName)
                .liquidH3()
                .foregroundStyle(Liquid.fg0)
                .lineLimit(1)
            Text(item.codigoInterno)
                .liquidMonoData(12, color: Liquid.fg2)
        }
    }

    private var choiceButtons: some View {
        HStack(spacing: Liquid.Space.md) {
            choiceButton("OK", color: Liquid.accentGreen) { onOK() }
            choiceButton("Com defeito", color: Liquid.accentRed) {
                withAnimation(Liquid.Motion.fast) { showingDefect = true }
            }
        }
    }

    private func choiceButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.liquidMono(13, weight: .medium))
                .textCase(.uppercase)
                .tracking(1.0)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Liquid.Space.md)
                .background(
                    RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous)
                        .strokeBorder(color, lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous)
                                .fill(color.opacity(0.10))
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var defectFields: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            Text("Novo desgaste")
                .liquidLabel()

            LiquidWearStepper(level: $desgaste)

            Text("Notas do defeito")
                .liquidLabel()

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
                .font(.liquidMono(13, weight: .medium))
                .textCase(.uppercase)
                .tracking(1.0)
                .foregroundStyle(enabled ? Liquid.bg0 : Liquid.fg3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Liquid.Space.md)
                .background(
                    RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous)
                        .fill(enabled ? Liquid.accentRed : Liquid.glassBg)
                        .liquidGlow(enabled ? Liquid.accentRed : .clear, radius: 14, opacity: enabled ? 0.4 : 0)
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
