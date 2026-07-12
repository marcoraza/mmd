import SwiftUI

private enum ReturnAssessmentMode {
    case problema
    case naoVoltou
}

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
    @State private var missingNotas = ""
    @State private var assessmentMode: ReturnAssessmentMode = .problema

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
                operationModeBanner
                    .padding(.horizontal, NDSpacing.medium)
                    .padding(.top, NDSpacing.medium)
                    .padding(.bottom, NDSpacing.compact)

                heroSummary
                    .padding(.horizontal, NDSpacing.medium)
                    .padding(.bottom, NDSpacing.medium)

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
        .onChange(of: viewModel.pendingAssessmentId) { id in
            guard let id,
                  let item = viewModel.outboundItems.first(where: { $0.id == id }) else { return }

            defectDesgaste = max(item.resolved.serialNumber.desgaste - 1, 1)
            defectNotas = ""
            missingNotas = ""
            assessmentMode = .problema
        }
    }

    // MARK: - Operational Mode

    private var operationModeBanner: some View {
        HStack(spacing: NDSpacing.base) {
            modeChip(
                label: viewModel.operationModeLabel,
                color: AppConfig.shared.isWebApiConfigured ? .ndSuccess : .ndWarning,
                active: true
            )

            modeChip(
                label: viewModel.scanMethod.displayName.uppercased(),
                color: .ndTextSecondary,
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

    // MARK: - Hero Summary

    private var heroSummary: some View {
        HStack(spacing: 0) {
            heroNumber("\(viewModel.okCount)", label: "OK", color: .ndSuccess)
            heroNumber("\(viewModel.problemCount)", label: "PROBLEMA", color: .ndWarning)
            heroNumber("\(viewModel.notReturnedCount)", label: "NAO VOLTOU", color: .ndAccent)
            heroNumber("\(viewModel.pendingCount)", label: "PENDENTE", color: .ndTextDisabled)
        }
        .background(Color.ndSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.ndBorderVisible, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func heroNumber(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: NDSpacing.tight) {
            Text(value)
                .font(.doto(28))
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
        .padding(.vertical, NDSpacing.compact)
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
                returnChecklistHeader

                ForEach(viewModel.outboundItems) { item in
                    returnItemRow(item)
                }
            }
        }
    }

    private var returnChecklistHeader: some View {
        VStack(alignment: .leading, spacing: NDSpacing.compact) {
            HStack {
                Text("UNIDADES QUE SAIRAM (\(viewModel.totalItems))")
                    .ndLabelSmall()

                Spacer()
            }

            if viewModel.pendingCount > 0 {
                warningRow("\(viewModel.pendingCount) unidade(s) sem conferencia.", color: .ndWarning)
            } else {
                warningRow("Checklist de retorno fechado.", color: .ndSuccess)
            }
        }
        .padding(.horizontal, NDSpacing.medium)
        .padding(.vertical, NDSpacing.compact)
    }

    private func returnItemRow(_ item: ReturnItemState) -> some View {
        let dotColor = returnStatusColor(item.result)
        let statusText = returnStatusText(item.result)

        return VStack(alignment: .leading, spacing: NDSpacing.compact) {
            HStack(spacing: NDSpacing.compact) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: NDSpacing.tight) {
                    Text(item.resolved.displayName)
                        .font(.ndBodySm)
                        .foregroundStyle(Color.ndTextPrimary)
                        .lineLimit(1)

                    Text("\(item.resolved.codigoInterno) | \(item.resolved.categoria.displayName.uppercased())")
                        .font(.spaceMono(9))
                        .tracking(9 * 0.08)
                        .foregroundStyle(Color.ndTextDisabled)
                        .lineLimit(1)
                }

                Spacer()

                Text(statusText)
                    .font(.spaceMono(10))
                    .tracking(10 * 0.08)
                    .foregroundStyle(dotColor)
            }

            HStack(spacing: NDSpacing.base) {
                actionPill("OK", color: .ndSuccess, active: isOK(item.result)) {
                    viewModel.markAsOK(serialId: item.id)
                }

                actionPill("Problema", color: .ndWarning, active: isProblem(item.result)) {
                    assessmentMode = .problema
                    viewModel.openAssessment(serialId: item.id)
                }

                actionPill("Nao voltou", color: .ndAccent, active: isNotReturned(item.result)) {
                    assessmentMode = .naoVoltou
                    viewModel.openAssessment(serialId: item.id)
                }
            }

            if let note = observationText(for: item.result) {
                Text("OBS DO EVENTO: \(note)")
                    .font(.spaceMono(9))
                    .tracking(9 * 0.04)
                    .foregroundStyle(dotColor)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, NDSpacing.medium)
        .padding(.vertical, NDSpacing.compact)
        .background(dotColor.opacity(isPending(item.result) ? 0.04 : 0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(dotColor.opacity(isPending(item.result) ? 0.15 : 0.55), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, NDSpacing.medium)
        .padding(.bottom, NDSpacing.base)
    }

    private func actionPill(_ label: String, color: Color, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.spaceMono(10))
                .tracking(10 * 0.04)
                .foregroundStyle(active ? Color.ndBlack : color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(active ? color : Color.clear, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(color.opacity(active ? 0 : 0.85), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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

    private func returnStatusColor(_ result: ReturnResult) -> Color {
        switch result {
        case .pending: return .ndTextDisabled
        case .ok: return .ndSuccess
        case .problema: return .ndWarning
        case .naoVoltou: return .ndAccent
        }
    }

    private func returnStatusText(_ result: ReturnResult) -> String {
        switch result {
        case .pending: return "PENDENTE"
        case .ok: return "OK"
        case .problema: return "PROBLEMA"
        case .naoVoltou: return "NAO VOLTOU"
        }
    }

    private func observationText(for result: ReturnResult) -> String? {
        switch result {
        case .problema(let notas, _):
            return notas
        case .naoVoltou(let notas):
            return notas
        case .pending, .ok:
            return nil
        }
    }

    private func isPending(_ result: ReturnResult) -> Bool {
        if case .pending = result { return true }
        return false
    }

    private func isOK(_ result: ReturnResult) -> Bool {
        if case .ok = result { return true }
        return false
    }

    private func isProblem(_ result: ReturnResult) -> Bool {
        if case .problema = result { return true }
        return false
    }

    private func isNotReturned(_ result: ReturnResult) -> Bool {
        if case .naoVoltou = result { return true }
        return false
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

                if viewModel.canFinalize {
                    Button {
                        Task { await viewModel.finalizeReturn() }
                    } label: {
                        Text("CONFIRMAR RETORNO (\(viewModel.resolvedCount))")
                            .font(.spaceMono(13, weight: .bold))
                            .tracking(13 * 0.08)
                            .foregroundStyle(Color.ndBlack)
                            .padding(.horizontal, NDSpacing.section)
                            .padding(.vertical, NDSpacing.compact)
                            .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isProcessingReturn)
                } else {
                    Text("\(viewModel.pendingCount) PENDENTE")
                        .font(.spaceMono(11, weight: .bold))
                        .tracking(11 * 0.08)
                        .foregroundStyle(Color.ndWarning)
                        .padding(.horizontal, NDSpacing.medium)
                        .padding(.vertical, NDSpacing.compact)
                        .background(
                            Capsule()
                                .strokeBorder(Color.ndWarning.opacity(0.55), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, NDSpacing.medium)
            .padding(.vertical, NDSpacing.compact)
        }
        .background(Color.ndBlack)
    }

    // MARK: - Assessment Modal

    private var assessmentModal: some View {
        let confirmDisabled = assessmentMode == .problema
            && defectNotas.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let confirmColor: Color = assessmentMode == .problema ? .ndWarning : .ndAccent

        return ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: NDSpacing.section) {
                Text(assessmentMode == .problema ? "PROBLEMA NA UNIDADE" : "UNIDADE NAO VOLTOU")
                    .font(.ndSubheading)
                    .foregroundStyle(Color.ndTextDisplay)

                if let id = viewModel.pendingAssessmentId,
                   let item = viewModel.outboundItems.first(where: { $0.id == id }) {
                    VStack(spacing: NDSpacing.tight) {
                        Text(item.resolved.displayName)
                            .font(.ndBodySm)
                            .foregroundStyle(Color.ndTextSecondary)
                            .lineLimit(1)

                        Text(item.resolved.codigoInterno)
                            .font(.spaceMono(10))
                            .tracking(10 * 0.08)
                            .foregroundStyle(Color.ndTextDisabled)
                    }
                }

                HStack(spacing: NDSpacing.base) {
                    modalChoice("OK", color: .ndSuccess, active: false) {
                        if let id = viewModel.pendingAssessmentId { viewModel.markAsOK(serialId: id) }
                    }

                    modalChoice("Problema", color: .ndWarning, active: assessmentMode == .problema) {
                        assessmentMode = .problema
                    }

                    modalChoice("Nao voltou", color: .ndAccent, active: assessmentMode == .naoVoltou) {
                        assessmentMode = .naoVoltou
                    }
                }

                if assessmentMode == .problema {
                    VStack(alignment: .leading, spacing: NDSpacing.compact) {
                        Text("OBS DO EVENTO")
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
                } else {
                    VStack(alignment: .leading, spacing: NDSpacing.compact) {
                        Text("OBS DO EVENTO")
                            .ndLabelSmall()

                        TextField("Ex: nao localizado no retorno.", text: $missingNotas, axis: .vertical)
                            .font(.ndBodySm)
                            .foregroundStyle(Color.ndTextPrimary)
                            .lineLimit(3...5)
                            .padding(NDSpacing.compact)
                            .background(Color.ndSurfaceRaised)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.ndBorder, lineWidth: 1)
                            )
                    }
                }

                Button {
                    if let id = viewModel.pendingAssessmentId {
                        switch assessmentMode {
                        case .problema:
                            viewModel.markAsProblem(
                                serialId: id,
                                notas: defectNotas,
                                desgaste: defectDesgaste
                            )
                        case .naoVoltou:
                            viewModel.markAsNotReturned(serialId: id, notas: missingNotas)
                        }
                    }
                } label: {
                    Text(assessmentMode == .problema ? "CONFIRMAR PROBLEMA" : "CONFIRMAR NAO VOLTOU")
                        .font(.spaceMono(13, weight: .bold))
                        .tracking(13 * 0.08)
                        .foregroundStyle(Color.ndBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, NDSpacing.compact)
                        .background(confirmColor, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(confirmDisabled)
                .opacity(confirmDisabled ? 0.5 : 1.0)
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

    private func modalChoice(_ label: String, color: Color, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.spaceMono(10, weight: .bold))
                .tracking(10 * 0.04)
                .foregroundStyle(active ? Color.ndBlack : color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, NDSpacing.base)
                .background(active ? color : Color.clear, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(color.opacity(active ? 0 : 0.9), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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
