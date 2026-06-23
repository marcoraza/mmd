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
    }
}

// MARK: - Content

private struct LiquidCheckoutValidationContent: View {

    let project: Project

    @StateObject private var viewModel: CheckoutViewModel

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
            CausticBackground(intensity: .work).ignoresSafeArea()

            VStack(spacing: 0) {
                validationPanel
                scanLayer
            }

            if showConfirmation {
                confirmationOverlay
            }
        }
        .navigationTitle("Confirmar saída")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.loadPackingList() }
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
        GlassCard(strong: true) {
            HStack(spacing: Liquid.Space.xl) {
                ReadinessGauge(
                    progress: progress,
                    diameter: Liquid.Ring.sizeMd,
                    stroke: Liquid.Ring.strokeMd,
                    caption: nil
                )

                VStack(alignment: .leading, spacing: Liquid.Space.xs) {
                    Text(project.nome)
                        .liquidH3()
                        .foregroundStyle(Liquid.fg0)
                        .lineLimit(1)

                    Text("\(viewModel.totalScanned) de \(viewModel.totalExpected) conferidos")
                        .liquidMonoData(12, color: Liquid.fg2)

                    if let cliente = project.cliente {
                        Text(cliente)
                            .liquidSmall()
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var packingList: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            Text("Packing list")
                .liquidLabel()

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
                .liquidGlow(color, radius: 5, opacity: 0.7)

            VStack(alignment: .leading, spacing: Liquid.Space.xxs) {
                Text(item.displayName)
                    .liquidBody()
                    .foregroundStyle(Liquid.fg0)
                    .lineLimit(1)

                if let categoria = item.item?.categoria {
                    Text(categoria.displayName)
                        .liquidLabel(categoria.liquidColor)
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
        .glassSurface(cornerRadius: Liquid.Radius.md, strong: true)
    }

    private var extrasSection: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            Text("Itens fora da lista")
                .liquidLabel(Liquid.accentRed)

            Text("Estes itens foram lidos mas não estão no packing. Remova-os antes de confirmar.")
                .liquidSmall()

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
                    .glassSurface(cornerRadius: Liquid.Radius.md, strong: true)
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
                isEnabled: viewModel.canFinalize
            ) {
                showConfirmation = true
            },
            onQRFallback: { showQRScanner = true },
            errorMessage: viewModel.error
        )
        .frame(maxHeight: .infinity)
    }

    // MARK: - Confirmation Overlay

    private var confirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    if !viewModel.isProcessingCheckout { showConfirmation = false }
                }

            GlassCard(strong: true) {
                VStack(spacing: Liquid.Space.xl) {
                    Text("Confirmar saída")
                        .liquidH2()

                    Text("\(viewModel.totalScanned) itens vão para EM CAMPO no projeto \(project.nome).")
                        .liquidBody()
                        .multilineTextAlignment(.center)

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
            }
            .padding(Liquid.Space.xxl)
        }
        .liquidElevatedShadow()
    }

    private func secondaryButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.liquidMono(13, weight: .medium))
                .textCase(.uppercase)
                .tracking(1.0)
                .foregroundStyle(Liquid.fg1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Liquid.Space.md)
                .background(
                    RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous)
                        .strokeBorder(Liquid.glassBorderStrong, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func primaryButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.liquidMono(13, weight: .medium))
                .textCase(.uppercase)
                .tracking(1.0)
                .foregroundStyle(Liquid.bg0)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Liquid.Space.md)
                .background(
                    RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous)
                        .fill(Liquid.accentGreen)
                        .liquidGlow(Liquid.accentGreen, radius: 16, opacity: 0.4)
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
