import SwiftUI

// MARK: - LiquidCheckoutValidationView
//
// Camada de validacao de check-out sobre o ScanEngine. O motor le o lote
// (RFID via fundacao, QR via fallback) e o CheckoutViewModel valida contra a
// packing list em tempo real. ReadinessGauge mostra o progresso da saida;
// a acao primaria "Confirmar saida" registra EM_CAMPO quando o lote bate.
//
// Wrapper publico: o contrato e LiquidCheckoutValidationView(project:). Os
// EnvironmentObjects nao chegam no init, entao este wrapper le rfid/api e
// repassa pro conteudo, que e dono do @StateObject do view model.

// O modo Conferencia (LiquidCheckoutGridView) saiu do toggle: e mockup com
// dado de exemplo. Volta quando o grid for alimentado pelo estado real do
// scan.

struct LiquidCheckoutValidationView: View {

    let project: Project

    @EnvironmentObject private var rfid: RFIDManager
    @EnvironmentObject private var apiClient: APIClient

    var body: some View {
        LiquidCheckoutValidationContent(
            project: project,
            apiClient: apiClient,
            rfidManager: rfid
        )
        .environmentObject(rfid)
        .navigationTitle("Check-out")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Content

private struct LiquidCheckoutValidationContent: View {

    let project: Project

    @StateObject private var viewModel: CheckoutViewModel

    @EnvironmentObject private var router: LiquidRouter
    @State private var showConfirmation = false
    @State private var showQRScanner = false

    init(project: Project, apiClient: APIClient, rfidManager: RFIDManager) {
        self.project = project
        _viewModel = StateObject(wrappedValue: CheckoutViewModel(
            project: project,
            apiClient: apiClient,
            rfidManager: rfidManager
        ))
    }

    private var progress: Double {
        guard viewModel.totalExpected > 0 else { return 0 }
        return Double(viewModel.totalScanned) / Double(viewModel.totalExpected)
    }

    var body: some View {
        ZStack {
            TechnicalGridCanvas()

            VStack(spacing: 0) {
                validationPanel
                scanLayer
            }

            if showConfirmation {
                confirmationOverlay
            }

            if viewModel.checkoutComplete {
                LiquidCompletionOverlay(
                    title: "Saída confirmada",
                    message: "\(viewModel.totalScanned) itens em campo no evento \(project.nome)."
                ) {
                    router.popToRoot()
                }
            }
        }
        .task {
            await viewModel.loadPackingList()
            viewModel.runDemoScanIfNeeded()
        }
        .onChange(of: viewModel.checkoutComplete) { complete in
            if complete { showConfirmation = false }
        }
        .sheet(isPresented: $showQRScanner) {
            LiquidQRScannerSheet { code in
                viewModel.processQRCode(code)
            }
        }
    }

    // MARK: - Validation Panel

    private var validationPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Liquid.Space.lg) {
                progressHeader

                if !viewModel.packingListItems.isEmpty {
                    packingList
                }

                if !viewModel.extraItems.isEmpty {
                    extrasSection
                }
            }
            .padding(Liquid.Space.xxl)
            .padding(.bottom, Liquid.Space.md)
        }
        .frame(maxHeight: .infinity)
    }

    private var progressHeader: some View {
        HStack(spacing: Liquid.Space.xl) {
            ReadinessGauge(
                progress: progress,
                diameter: 56,
                stroke: 5,
                caption: nil
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(project.nome)
                    .font(.liquidSans(17, weight: .semibold))
                    .foregroundStyle(Liquid.fg0)
                    .lineLimit(1)

                (Text("\(viewModel.totalScanned)").foregroundColor(Liquid.fg0)
                    + Text(" de \(viewModel.totalExpected) conferidos").foregroundColor(Liquid.fg2))
                    .font(.liquidMono(12, weight: .medium))

                if let cliente = project.cliente {
                    Text(cliente)
                        .font(.liquidSans(12, weight: .regular))
                        .foregroundStyle(Liquid.fg2)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Liquid.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelSurface(cornerRadius: Liquid.Radius.lg)
        .tourAnchor(.checkoutScan)
    }

    private var packingList: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            LiquidSectionHeader(
                title: "Packing list",
                trailing: "\(viewModel.packingListItems.count) linhas"
            )

            VStack(spacing: Liquid.Space.sm) {
                ForEach(viewModel.packingListItems) { item in
                    packingRow(item)
                }
            }
        }
    }

    private func packingRow(_ item: PackingListItem) -> some View {
        let matched = viewModel.matchedCounts[item.id] ?? 0
        let validation = viewModel.validationState(for: item)
        let color: Color = {
            switch validation {
            case .pending: return Liquid.accentAmber
            case .complete: return Liquid.accentGreen
            case .over: return Liquid.accentRed
            }
        }()

        return HStack(spacing: Liquid.Space.md) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: Liquid.Space.xxs) {
                Text(item.displayName)
                    .font(.liquidSans(14, weight: .medium))
                    .foregroundStyle(Liquid.fg0)
                    .lineLimit(1)

                if let categoria = item.item?.categoria {
                    Text(categoria.displayName)
                        .font(.liquidSans(11, weight: .medium))
                        .foregroundStyle(Liquid.fg2)
                }
            }

            Spacer(minLength: Liquid.Space.sm)

            Text("\(matched)/\(item.quantidade)")
                .font(.liquidMono(15, weight: .medium))
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, Liquid.Space.lg)
        .padding(.vertical, Liquid.Space.md)
        .panelSurface(cornerRadius: Liquid.Radius.md)
    }

    private var extrasSection: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            LiquidSectionHeader(
                title: "Fora da lista",
                trailing: "\(viewModel.extraItems.count)"
            )

            Text("Estes itens foram lidos mas não estão no packing. Remova-os antes de confirmar.")
                .font(.liquidSans(13, weight: .regular))
                .foregroundStyle(Liquid.fg2)

            VStack(spacing: Liquid.Space.sm) {
                ForEach(viewModel.extraItems, id: \.serialNumber.id) { item in
                    HStack(spacing: Liquid.Space.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Liquid.accentRed)

                        VStack(alignment: .leading, spacing: Liquid.Space.xxs) {
                            Text(item.displayName)
                                .liquidBody()
                                .foregroundStyle(Liquid.fg0)
                                .lineLimit(1)
                            Text(item.codigoInterno)
                                .liquidMonoData(11, color: Liquid.fg2)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Liquid.Space.lg)
                    .padding(.vertical, Liquid.Space.md)
                    .panelSurface(cornerRadius: Liquid.Radius.md)
                }
            }
        }
    }

    // MARK: - Scan Layer

    private var scanLayer: some View {
        ScanEngine(
            heroUnit: "TAGS LIDAS",
            emptyHint: "Aponte o leitor pra conferir a saída do projeto",
            primaryAction: ScanAction(
                label: "Confirmar saída",
                isEnabled: viewModel.canFinalize,
                disabledHint: finalizeHint
            ) {
                showConfirmation = true
            },
            onQRFallback: { showQRScanner = true },
            onNeedsReader: { router.push(.conectar) },
            errorMessage: viewModel.error
        )
        .frame(maxHeight: .infinity)
    }

    /// Motivo do "Confirmar saída" travado, na ordem em que o operador
    /// consegue agir: extras primeiro, depois o que falta ler.
    private var finalizeHint: String? {
        guard !viewModel.canFinalize else { return nil }
        guard !viewModel.packingListItems.isEmpty else { return nil }

        if !viewModel.extraItems.isEmpty {
            return "Remova os itens fora da lista pra liberar a saída"
        }

        let faltam = viewModel.packingListItems.reduce(0) {
            $0 + max(0, $1.quantidade - (viewModel.matchedCounts[$1.id] ?? 0))
        }
        guard faltam > 0 else { return nil }
        return faltam == 1
            ? "Falta 1 item pra liberar a saída"
            : "Faltam \(faltam) itens pra liberar a saída"
    }

    // MARK: - Confirmation Overlay

    private var confirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    if !viewModel.isProcessingCheckout { showConfirmation = false }
                }

            VStack(spacing: Liquid.Space.xl) {
                VStack(spacing: Liquid.Space.xs) {
                    Text("Confirmar saída")
                        .font(.liquidSans(20, weight: .semibold))
                        .foregroundStyle(Liquid.fg0)

                    Text("\(viewModel.totalScanned) itens vão para EM CAMPO no evento \(project.nome).")
                        .font(.liquidSans(14, weight: .regular))
                        .foregroundStyle(Liquid.fg1)
                        .multilineTextAlignment(.center)
                }

                if viewModel.isProcessingCheckout {
                    ProgressView().tint(Liquid.fg1)
                } else {
                    HStack(spacing: Liquid.Space.md) {
                        secondaryButton("Cancelar") { showConfirmation = false }
                        primaryButton("Confirmar") {
                            Task { await viewModel.finalizeCheckout() }
                        }
                    }
                }
            }
            .padding(Liquid.Space.xxl)
            .panelSurface(cornerRadius: Liquid.Radius.lg)
            .padding(Liquid.Space.xxl)
        }
        .liquidElevatedShadow()
    }

    private func secondaryButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.liquidSans(15, weight: .semibold))
                .foregroundStyle(Liquid.fg1)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background {
                    let shape = RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                    shape.fill(Liquid.bg2)
                        .overlay(shape.strokeBorder(Liquid.hairlineStrong, lineWidth: 1))
                }
        }
        .buttonStyle(.plain)
    }

    private func primaryButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.liquidSans(15, weight: .semibold))
                .foregroundStyle(Liquid.bg0)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                        .fill(Liquid.accentGreen)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct LiquidCheckoutValidationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LiquidCheckoutValidationView(
                project: Project(
                    id: UUID(),
                    nome: "Festival de Verão",
                    cliente: "Produções XYZ",
                    status: .confirmado
                )
            )
            .environmentObject(RFIDManager(useMock: true))
            .environmentObject(APIClient())
        }
        .preferredColorScheme(.dark)
    }
}
#endif
