import SwiftUI

// MARK: - ScanMethodToggle

/// Segmented control for choosing RFID or QR Code scan method.
struct ScanMethodToggle: View {

    @Binding var method: MetodoScan

    var body: some View {
        HStack(spacing: 2) {
            toggleButton("RFID", isActive: method == .rfid) {
                method = .rfid
            }
            toggleButton("QR CODE", isActive: method == .qrcode) {
                method = .qrcode
            }
        }
        .background(Color.ndSurface)
        .clipShape(Capsule())
    }

    private func toggleButton(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.spaceMono(11))
                .tracking(11 * 0.08)
                .textCase(.uppercase)
                .foregroundStyle(isActive ? Color.ndTextDisplay : Color.ndTextDisabled)
                .padding(.horizontal, NDSpacing.medium)
                .padding(.vertical, NDSpacing.base)
                .background(
                    isActive
                        ? Capsule().strokeBorder(Color.ndBorderVisible, lineWidth: 1)
                        : Capsule().strokeBorder(Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CheckoutFlowView

/// Checkout flow: scan equipment against packing list with real-time validation.
struct CheckoutFlowView: View {

    let project: Project
    let rfidManager: RFIDManager

    @StateObject private var viewModel: CheckoutViewModel

    @State private var showConfirmation = false
    @State private var qrScanActive = false
    @State private var scanPulse = false

    init(project: Project, apiClient: APIClient, rfidManager: RFIDManager) {
        self.project = project
        self.rfidManager = rfidManager
        _viewModel = StateObject(wrappedValue: CheckoutViewModel(
            project: project,
            apiClient: apiClient,
            rfidManager: rfidManager
        ))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Operational mode
                operationModeBanner
                    .padding(.horizontal, NDSpacing.medium)
                    .padding(.top, NDSpacing.medium)
                    .padding(.bottom, NDSpacing.compact)

                // Event summary
                eventSummaryCard
                    .padding(.horizontal, NDSpacing.medium)
                    .padding(.bottom, NDSpacing.medium)

                // Hero progress
                heroProgress
                    .padding(.bottom, NDSpacing.medium)

                // Scan method toggle
                ScanMethodToggle(method: $viewModel.scanMethod)
                    .padding(.horizontal, NDSpacing.medium)
                    .padding(.bottom, NDSpacing.medium)

                // 1px separator
                Rectangle()
                    .fill(Color.ndBorder)
                    .frame(height: 1)

                // Scan area or packing list
                if viewModel.scanMethod == .qrcode {
                    qrScanArea
                        .frame(height: 200)

                    Rectangle()
                        .fill(Color.ndBorder)
                        .frame(height: 1)
                }

                // Packing list with validation
                packingListSection

                Spacer()

                // Bottom controls
                bottomBar
            }
            .background(Color.ndBlack)

            // Confirmation modal overlay
            if showConfirmation {
                confirmationModal
            }
        }
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.loadPackingList() }
        .onChange(of: viewModel.checkoutComplete) { complete in
            if complete {
                showConfirmation = false
            }
        }
    }

    // MARK: - Operational Mode

    private var operationModeBanner: some View {
        HStack(spacing: NDSpacing.base) {
            modeChip(
                label: AppConfig.shared.isWebApiConfigured ? "API REAL" : "MODO MOCK",
                color: AppConfig.shared.isWebApiConfigured ? .ndSuccess : .ndWarning,
                active: true
            )

            modeChip(
                label: AppConfig.shared.isWebApiConfigured ? "MOCK OFF" : "API REAL OFF",
                color: .ndTextDisabled,
                active: false
            )

            Spacer()
        }
    }

    private func modeChip(label: String, color: Color, active: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.spaceMono(10))
                .tracking(10 * 0.08)
                .foregroundStyle(active ? color : Color.ndTextDisabled)
        }
        .padding(.horizontal, NDSpacing.compact)
        .padding(.vertical, 7)
        .background(Color.ndSurface)
        .overlay(
            Capsule()
                .stroke(active ? color.opacity(0.55) : Color.ndBorder, lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    // MARK: - Event Summary

    private var eventSummaryCard: some View {
        let summary = viewModel.eventSummary
        let title = summary?.nome ?? project.nome
        let client = summary?.cliente ?? project.cliente
        let setup = summary?.displaySetup ?? project.dataInicio ?? "-"
        let teardown = summary?.displayTeardown ?? project.dataFim ?? "-"
        let local = summary?.displayLocal ?? project.local ?? "-"
        let contact = summary?.displayContact ?? project.cliente ?? "-"
        let readiness = summary?.packing.readinessPct ?? readinessFromLocalPacking

        return HStack(alignment: .center, spacing: NDSpacing.medium) {
            VStack(alignment: .leading, spacing: NDSpacing.compact) {
                VStack(alignment: .leading, spacing: NDSpacing.tight) {
                    Text(title)
                        .font(.ndBody)
                        .foregroundStyle(Color.ndTextDisplay)
                        .lineLimit(2)

                    if let client {
                        Text(client)
                            .font(.spaceMono(10))
                            .tracking(10 * 0.08)
                            .foregroundStyle(Color.ndTextSecondary)
                            .lineLimit(1)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    summaryLine(icon: "calendar", label: "Setup", value: setup)
                    summaryLine(icon: "calendar.badge.clock", label: "Desmontagem", value: teardown)
                    summaryLine(icon: "mappin.and.ellipse", label: "Local", value: local)
                    summaryLine(icon: "person", label: "Contato", value: contact)
                }

                if let notice = viewModel.summaryNotice {
                    Text(notice.uppercased())
                        .font(.spaceMono(8))
                        .tracking(8 * 0.08)
                        .foregroundStyle(Color.ndTextDisabled)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: NDSpacing.compact)

            readinessRing(readiness: readiness)
        }
        .padding(NDSpacing.medium)
        .background(Color.ndSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.ndBorderVisible, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func summaryLine(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(Color.ndTextDisabled)
                .frame(width: 14)

            Text(label)
                .font(.spaceMono(9))
                .tracking(9 * 0.08)
                .foregroundStyle(Color.ndTextDisabled)

            Text(value)
                .font(.spaceMono(10))
                .tracking(10 * 0.04)
                .foregroundStyle(Color.ndTextSecondary)
                .lineLimit(1)
        }
    }

    private func readinessRing(readiness: Int) -> some View {
        ZStack {
            Circle()
                .stroke(Color.ndBorderVisible, lineWidth: 8)

            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(readiness, 100))) / 100)
                .stroke(
                    AppConfig.shared.isWebApiConfigured ? Color.ndSuccess : Color.ndWarning,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text("\(readiness)%")
                    .font(.spaceMono(16, weight: .bold))
                    .foregroundStyle(Color.ndTextDisplay)

                Text("READY")
                    .font(.spaceMono(8))
                    .tracking(8 * 0.08)
                    .foregroundStyle(Color.ndTextDisabled)
            }
        }
        .frame(width: 78, height: 78)
    }

    private var readinessFromLocalPacking: Int {
        guard viewModel.totalExpected > 0 else { return 0 }
        return Int((Double(viewModel.totalScanned) / Double(viewModel.totalExpected) * 100).rounded())
    }

    // MARK: - Hero Progress

    private var heroProgress: some View {
        VStack(spacing: NDSpacing.base) {
            Text("\(viewModel.totalScanned)/\(viewModel.totalExpected)")
                .font(.displayLG)
                .foregroundStyle(Color.ndTextDisplay)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: viewModel.totalScanned)

            ProgressSegmentBar(
                total: viewModel.totalExpected,
                filled: viewModel.totalScanned,
                filledColor: .ndSuccess
            )
            .padding(.horizontal, NDSpacing.wide)
        }
    }

    // MARK: - QR Scan Area

    private var qrScanArea: some View {
        ZStack {
            QRScanView(isActive: $qrScanActive) { code in
                viewModel.processQRCode(code)
            }

            QRScanOverlay()

            // 1px border
            Rectangle()
                .strokeBorder(Color.ndBorderVisible, lineWidth: 1)
        }
        .onAppear { qrScanActive = true }
        .onDisappear { qrScanActive = false }
    }

    // MARK: - Packing List Section

    private var packingListSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                preConfirmWarnings

                ForEach(viewModel.packingListItems) { item in
                    packingItemRow(item)

                    Rectangle()
                        .fill(Color.ndBorder)
                        .frame(height: 1)
                        .padding(.leading, NDSpacing.medium)
                }

                // Extra items (not in packing list)
                if !viewModel.extraItems.isEmpty {
                    HStack {
                        Text("ITENS EXTRAS")
                            .ndLabelSmallAccent(.ndAccent)
                        Spacer()
                    }
                    .padding(.horizontal, NDSpacing.medium)
                    .padding(.vertical, NDSpacing.compact)

                    ForEach(viewModel.extraItems, id: \.serialNumber.id) { item in
                        extraItemRow(item)

                        Rectangle()
                            .fill(Color.ndBorder)
                            .frame(height: 1)
                            .padding(.leading, NDSpacing.medium)
                    }
                }
            }
        }
    }

    private var preConfirmWarnings: some View {
        VStack(alignment: .leading, spacing: NDSpacing.compact) {
            HStack {
                Text("ATENCAO ANTES DE CONFIRMAR")
                    .ndLabelSmall()
                Spacer()
            }

            if viewModel.checkoutWarnings.isEmpty {
                warningRow("Checklist batendo com o packing.", color: .ndSuccess)
            } else {
                ForEach(viewModel.checkoutWarnings, id: \.self) { warning in
                    warningRow(warning, color: .ndAccent)
                }
            }
        }
        .padding(.horizontal, NDSpacing.medium)
        .padding(.vertical, NDSpacing.compact)
        .background(Color.ndBlack)
    }

    private func warningRow(_ text: String, color: Color) -> some View {
        HStack(spacing: NDSpacing.base) {
            Circle()
                .stroke(color, lineWidth: 2)
                .frame(width: 11, height: 11)

            Text(text)
                .font(.ndBodySm)
                .foregroundStyle(color)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, NDSpacing.compact)
        .padding(.vertical, NDSpacing.base)
        .background(Color.ndSurfaceRaised)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func packingItemRow(_ item: PackingListItem) -> some View {
        let matched = viewModel.matchedCounts[item.id] ?? 0
        let validation = viewModel.validationState(for: item)
        let color: Color = {
            switch validation {
            case .pending: return .ndWarning
            case .complete: return .ndSuccess
            case .over: return .ndAccent
            }
        }()

        return HStack(spacing: NDSpacing.compact) {
            VStack(alignment: .leading, spacing: NDSpacing.tight) {
                Text(item.displayName)
                    .font(.ndBodySm)
                    .foregroundStyle(Color.ndTextPrimary)
                    .lineLimit(1)

                if let categoria = item.item?.categoria {
                    Text(categoria.displayName.uppercased())
                        .font(.spaceMono(9))
                        .tracking(9 * 0.08)
                        .foregroundStyle(categoria.color)
                }
            }

            Spacer()

            Text("\(matched)/\(item.quantidade)")
                .font(.spaceMono(14))
                .foregroundStyle(color)
        }
        .padding(.horizontal, NDSpacing.medium)
        .padding(.vertical, 14)
    }

    private func extraItemRow(_ item: ResolvedItem) -> some View {
        HStack(spacing: NDSpacing.compact) {
            VStack(alignment: .leading, spacing: NDSpacing.tight) {
                Text(item.displayName)
                    .font(.ndBodySm)
                    .foregroundStyle(Color.ndAccent)
                    .lineLimit(1)

                Text(item.codigoInterno)
                    .font(.spaceMono(9))
                    .tracking(9 * 0.08)
                    .foregroundStyle(Color.ndAccent.opacity(0.7))
            }

            Spacer()

            Text("NAO NA LISTA")
                .font(.spaceMono(9))
                .tracking(9 * 0.08)
                .foregroundStyle(Color.ndAccent)
        }
        .padding(.horizontal, NDSpacing.medium)
        .padding(.vertical, 14)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // Error
            if let error = viewModel.error {
                Text(error)
                    .font(.spaceMono(11))
                    .foregroundStyle(Color.ndAccent)
                    .padding(.horizontal, NDSpacing.medium)
                    .padding(.vertical, NDSpacing.base)
            }

            Rectangle()
                .fill(Color.ndBorder)
                .frame(height: 1)

            HStack(spacing: NDSpacing.compact) {
                // RFID scan controls (only when RFID mode)
                if viewModel.scanMethod == .rfid {
                    // Tag count
                    Text("\(rfidManager.tagCount)")
                        .font(.spaceMono(14))
                        .foregroundStyle(Color.ndTextSecondary)

                    Text("TAGS")
                        .font(.spaceMono(9))
                        .tracking(9 * 0.08)
                        .foregroundStyle(Color.ndTextDisabled)

                    Spacer()

                    // Scan button
                    Button {
                        if rfidManager.isScanning {
                            rfidManager.stopInventory()
                        } else {
                            rfidManager.startInventory()
                        }
                    } label: {
                        Text(rfidManager.isScanning ? "PARAR" : "ESCANEAR")
                            .font(.spaceMono(13))
                            .tracking(13 * 0.08)
                            .foregroundStyle(
                                rfidManager.isScanning ? Color.ndTextDisplay : Color.ndBlack
                            )
                            .padding(.horizontal, NDSpacing.section)
                            .padding(.vertical, NDSpacing.compact)
                            .background(
                                Group {
                                    if rfidManager.isScanning {
                                        Capsule()
                                            .strokeBorder(Color.ndTextDisplay, lineWidth: 1)
                                            .opacity(scanPulse ? 0.6 : 1.0)
                                    } else {
                                        Capsule()
                                            .fill(Color.white)
                                    }
                                }
                            )
                            .scaleEffect(rfidManager.isScanning && scanPulse ? 1.03 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onChange(of: rfidManager.isScanning) { scanning in
                        if scanning {
                            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                                scanPulse = true
                            }
                        } else {
                            withAnimation(.easeOut(duration: 0.3)) {
                                scanPulse = false
                            }
                        }
                    }
                } else {
                    Spacer()
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text("FALTANDO \(viewModel.missingCount)")
                        .font(.spaceMono(9))
                        .tracking(9 * 0.08)
                        .foregroundStyle(viewModel.missingCount == 0 ? Color.ndSuccess : Color.ndWarning)

                    Text("EXTRA \(viewModel.extraItems.count)")
                        .font(.spaceMono(9))
                        .tracking(9 * 0.08)
                        .foregroundStyle(viewModel.extraItems.isEmpty ? Color.ndSuccess : Color.ndAccent)
                }

                // Finalizar button
                if viewModel.canFinalize {
                    Button {
                        showConfirmation = true
                    } label: {
                        Text("FINALIZAR")
                            .font(.spaceMono(13, weight: .bold))
                            .tracking(13 * 0.08)
                            .foregroundStyle(Color.ndBlack)
                            .padding(.horizontal, NDSpacing.section)
                            .padding(.vertical, NDSpacing.compact)
                            .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, NDSpacing.medium)
            .padding(.vertical, NDSpacing.compact)
        }
        .background(Color.ndBlack)
    }

    // MARK: - Confirmation Modal

    private var confirmationModal: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { showConfirmation = false }

            VStack(spacing: NDSpacing.section) {
                Text("CONFIRMAR CHECKOUT")
                    .font(.ndSubheading)
                    .foregroundStyle(Color.ndTextDisplay)

                Text("\(viewModel.totalScanned) itens serao registrados como EM CAMPO para o projeto \(project.nome).")
                    .font(.ndBodySm)
                    .foregroundStyle(Color.ndTextPrimary)
                    .multilineTextAlignment(.center)

                if !AppConfig.shared.isWebApiConfigured {
                    Text("Modo mock: nenhuma alteracao real sera gravada.")
                        .font(.spaceMono(10))
                        .tracking(10 * 0.08)
                        .foregroundStyle(Color.ndWarning)
                        .multilineTextAlignment(.center)
                }

                if viewModel.isProcessingCheckout {
                    ProgressView()
                        .tint(Color.ndTextSecondary)
                } else {
                    HStack(spacing: NDSpacing.medium) {
                        Button {
                            showConfirmation = false
                        } label: {
                            Text("CANCELAR")
                                .font(.spaceMono(13))
                                .tracking(13 * 0.08)
                                .foregroundStyle(Color.ndTextSecondary)
                                .padding(.horizontal, NDSpacing.section)
                                .padding(.vertical, NDSpacing.compact)
                                .background(
                                    Capsule()
                                        .strokeBorder(Color.ndBorderVisible, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task { await viewModel.finalizeCheckout() }
                        } label: {
                            Text("CONFIRMAR")
                                .font(.spaceMono(13, weight: .bold))
                                .tracking(13 * 0.08)
                                .foregroundStyle(Color.ndBlack)
                                .padding(.horizontal, NDSpacing.section)
                                .padding(.vertical, NDSpacing.compact)
                                .background(Color.white, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(NDSpacing.section)
            .background(Color.ndSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.ndBorderVisible, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, NDSpacing.wide)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CheckoutFlowView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CheckoutFlowView(
                project: Project(
                    id: UUID(),
                    nome: "Festival de Verao",
                    cliente: "Producoes XYZ",
                    dataInicio: "2026-04-15",
                    dataFim: "2026-04-17",
                    local: "Praia do Forte",
                    status: .confirmado
                ),
                apiClient: APIClient(),
                rfidManager: RFIDManager()
            )
            .environmentObject(APIClient())
            .environmentObject(RFIDManager())
        }
        .preferredColorScheme(.dark)
    }
}
#endif
