import SwiftUI

// MARK: - ReturnFlowView

/// Return flow: scan returned equipment, mark defects, register return via API.
struct ReturnFlowView: View {

    let project: Project
    let rfidManager: RFIDManager

    @StateObject private var viewModel: ReturnViewModel

    @State private var qrScanActive = false
    @State private var scanPulse = false
    @State private var defectNotas = ""
    @State private var defectDesgaste = 3

    init(project: Project, apiClient: APIClient, rfidManager: RFIDManager) {
        self.project = project
        self.rfidManager = rfidManager
        _viewModel = StateObject(wrappedValue: ReturnViewModel(
            project: project,
            apiClient: apiClient,
            rfidManager: rfidManager
        ))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Hero summary
                heroSummary
                    .padding(.vertical, NDSpacing.section)

                // Scan method toggle
                ScanMethodToggle(method: $viewModel.scanMethod)
                    .padding(.horizontal, NDSpacing.medium)
                    .padding(.bottom, NDSpacing.medium)

                // 1px separator
                Rectangle()
                    .fill(Color.ndBorder)
                    .frame(height: 1)

                // QR scan area
                if viewModel.scanMethod == .qrcode {
                    qrScanArea
                        .frame(height: 200)

                    Rectangle()
                        .fill(Color.ndBorder)
                        .frame(height: 1)
                }

                // Item list
                itemList

                Spacer()

                // Bottom bar
                bottomBar
            }
            .background(Color.ndBlack)

            // Condition assessment modal
            if viewModel.pendingAssessmentId != nil {
                assessmentModal
            }
        }
        .navigationTitle("Retorno")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.loadOutboundItems() }
    }

    // MARK: - Hero Summary

    private var heroSummary: some View {
        HStack(spacing: NDSpacing.wide) {
            heroNumber("\(viewModel.okCount)", label: "OK", color: .ndSuccess)
            heroNumber("\(viewModel.defectCount)", label: "DEFEITO", color: .ndAccent)
            heroNumber("\(viewModel.missingCount)", label: "FALTA", color: .ndWarning)
        }
        .padding(.horizontal, NDSpacing.medium)
    }

    private func heroNumber(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: NDSpacing.tight) {
            Text(value)
                .font(.displayMD)
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: value)

            Text(label)
                .font(.spaceMono(9))
                .tracking(9 * 0.08)
                .textCase(.uppercase)
                .foregroundStyle(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - QR Scan Area

    private var qrScanArea: some View {
        ZStack {
            QRScanView(isActive: $qrScanActive) { code in
                viewModel.processQRCode(code)
            }

            QRScanOverlay()

            Rectangle()
                .strokeBorder(Color.ndBorderVisible, lineWidth: 1)
        }
        .onAppear { qrScanActive = true }
        .onDisappear { qrScanActive = false }
    }

    // MARK: - Item List

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.outboundItems) { item in
                    returnItemRow(item)

                    Rectangle()
                        .fill(Color.ndBorder)
                        .frame(height: 1)
                        .padding(.leading, NDSpacing.medium)
                }
            }
        }
    }

    private func returnItemRow(_ item: ReturnItemState) -> some View {
        let dotColor: Color = {
            switch item.result {
            case .pending: return .ndWarning
            case .ok: return .ndSuccess
            case .defeito: return .ndAccent
            }
        }()

        let statusText: String = {
            switch item.result {
            case .pending: return "PENDENTE"
            case .ok: return "OK"
            case .defeito: return "DEFEITO"
            }
        }()

        return HStack(spacing: NDSpacing.compact) {
            // Status dot
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)

            VStack(alignment: .leading, spacing: NDSpacing.tight) {
                Text(item.resolved.displayName)
                    .font(.ndBodySm)
                    .foregroundStyle(Color.ndTextPrimary)
                    .lineLimit(1)

                Text(item.resolved.codigoInterno)
                    .font(.spaceMono(9))
                    .tracking(9 * 0.08)
                    .foregroundStyle(Color.ndTextDisabled)
            }

            Spacer()

            Text(statusText)
                .font(.spaceMono(11))
                .tracking(11 * 0.08)
                .foregroundStyle(dotColor)
        }
        .padding(.horizontal, NDSpacing.medium)
        .padding(.vertical, 14)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
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
                // RFID scan controls
                if viewModel.scanMethod == .rfid {
                    Text("\(rfidManager.tagCount)")
                        .font(.spaceMono(14))
                        .foregroundStyle(Color.ndTextSecondary)

                    Text("TAGS")
                        .font(.spaceMono(9))
                        .tracking(9 * 0.08)
                        .foregroundStyle(Color.ndTextDisabled)

                    Spacer()

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

                // Finalizar button
                if viewModel.canFinalize {
                    Button {
                        Task { await viewModel.finalizeReturn() }
                    } label: {
                        Text("FINALIZAR RETORNO")
                            .font(.spaceMono(13, weight: .bold))
                            .tracking(13 * 0.08)
                            .foregroundStyle(Color.ndBlack)
                            .padding(.horizontal, NDSpacing.section)
                            .padding(.vertical, NDSpacing.compact)
                            .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isProcessingReturn)
                }
            }
            .padding(.horizontal, NDSpacing.medium)
            .padding(.vertical, NDSpacing.compact)
        }
        .background(Color.ndBlack)
    }

    // MARK: - Assessment Modal

    private var assessmentModal: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: NDSpacing.section) {
                Text("CONDICAO DO ITEM")
                    .font(.ndSubheading)
                    .foregroundStyle(Color.ndTextDisplay)

                // Item name
                if let id = viewModel.pendingAssessmentId,
                   let item = viewModel.outboundItems.first(where: { $0.id == id }) {
                    Text(item.resolved.displayName)
                        .font(.ndBodySm)
                        .foregroundStyle(Color.ndTextSecondary)
                }

                // OK / COM DEFEITO buttons
                HStack(spacing: NDSpacing.medium) {
                    Button {
                        if let id = viewModel.pendingAssessmentId {
                            viewModel.markAsOK(serialId: id)
                        }
                    } label: {
                        Text("OK")
                            .font(.spaceMono(13, weight: .bold))
                            .tracking(13 * 0.08)
                            .foregroundStyle(Color.ndSuccess)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, NDSpacing.compact)
                            .background(
                                Capsule()
                                    .strokeBorder(Color.ndSuccess, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        // Show defect fields
                        defectNotas = ""
                        defectDesgaste = max((viewModel.outboundItems.first(where: { $0.id == viewModel.pendingAssessmentId })?.resolved.serialNumber.desgaste ?? 3) - 1, 1)
                    } label: {
                        Text("COM DEFEITO")
                            .font(.spaceMono(13, weight: .bold))
                            .tracking(13 * 0.08)
                            .foregroundStyle(Color.ndAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, NDSpacing.compact)
                            .background(
                                Capsule()
                                    .strokeBorder(Color.ndAccent, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                // Defect detail fields (always visible for simplicity, user picks OK or fills these)
                VStack(alignment: .leading, spacing: NDSpacing.compact) {
                    Text("NOTAS DO DEFEITO")
                        .ndLabelSmall()

                    TextField("Descreva o problema...", text: $defectNotas, axis: .vertical)
                        .font(.ndBodySm)
                        .foregroundStyle(Color.ndTextPrimary)
                        .lineLimit(3...6)
                        .padding(NDSpacing.compact)
                        .background(Color.ndSurfaceRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.ndBorder, lineWidth: 1)
                        )

                    InteractiveWearBarLabeled(level: $defectDesgaste)
                        .padding(.top, NDSpacing.base)
                }

                // Confirm defect button
                Button {
                    if let id = viewModel.pendingAssessmentId {
                        viewModel.markAsDefect(
                            serialId: id,
                            notas: defectNotas,
                            desgaste: defectDesgaste
                        )
                    }
                } label: {
                    Text("CONFIRMAR DEFEITO")
                        .font(.spaceMono(13, weight: .bold))
                        .tracking(13 * 0.08)
                        .foregroundStyle(Color.ndBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, NDSpacing.compact)
                        .background(Color.ndAccent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(defectNotas.isEmpty)
                .opacity(defectNotas.isEmpty ? 0.5 : 1.0)
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
struct ReturnFlowView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ReturnFlowView(
                project: Project(
                    id: UUID(),
                    nome: "Festival de Verao",
                    cliente: "Producoes XYZ",
                    dataInicio: "2026-04-15",
                    dataFim: "2026-04-17",
                    local: "Praia do Forte",
                    status: .emCampo,
                    notas: nil,
                    createdAt: nil,
                    updatedAt: nil
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
