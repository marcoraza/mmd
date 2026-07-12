import SwiftUI

// MARK: - IdentificarFlow
//
// Trilha Identificar: scan da tag, resultado do item. O scan e o ScanEngine da
// fundacao, gated por conexao (o leitor e pre-requisito de tudo). A acao
// Resolver le as tags contra o banco (apiClient.resolveRfidTags) e empurra o
// LiquidScanResultView com resolvidos e nao resolvidos.

struct IdentificarFlow: View {

    @EnvironmentObject private var rfid: RFIDManager
    @EnvironmentObject private var apiClient: APIClient
    @EnvironmentObject private var router: LiquidRouter

    @State private var isResolving = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            TechnicalGridCanvas()

            if rfid.isConnected {
                ScanEngine(
                    heroUnit: "TAGS",
                    emptyHint: "Aponte o leitor e pressione escanear",
                    primaryAction: ScanAction(
                        label: "Resolver",
                        isBusy: isResolving,
                        isEnabled: rfid.tagCount > 0 && !isResolving
                    ) {
                        resolve()
                    },
                    errorMessage: errorMessage
                )
            } else {
                NeedsReaderPrompt()
            }
        }
        .navigationTitle("Identificar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func resolve() {
        rfid.stopInventory()
        let tags = rfid.scannedTags
        guard !tags.isEmpty else { return }

        isResolving = true
        errorMessage = nil

        Task {
            do {
                let result = try await apiClient.resolveRfidTags(tags)
                isResolving = false
                router.push(.scanResult(ScanResultPayload(
                    resolved: result.resolved,
                    unresolved: result.unresolved
                )))
            } catch {
                errorMessage = error.localizedDescription
                isResolving = false
            }
        }
    }
}

// MARK: - NeedsReaderPrompt
//
// Compartilhado pelas trilhas que dependem de scan quando o leitor esta off.

struct NeedsReaderPrompt: View {

    @EnvironmentObject private var router: LiquidRouter

    var body: some View {
        ZStack {
            TechnicalGridCanvas()

            VStack(spacing: Liquid.Space.lg) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Liquid.fg2)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Liquid.bg2)
                    )

                VStack(spacing: Liquid.Space.xs) {
                    Text("Leitor desconectado")
                        .font(.liquidSans(17, weight: .semibold))
                        .foregroundStyle(Liquid.fg0)

                    Text("Conecte o RFD40 pra escanear.")
                        .font(.liquidSans(14, weight: .regular))
                        .foregroundStyle(Liquid.fg2)
                        .multilineTextAlignment(.center)
                }

                Button { router.push(.conectar) } label: {
                    Text("Conectar leitor")
                        .font(.liquidSans(15, weight: .semibold))
                        .foregroundStyle(Liquid.bg0)
                        .padding(.horizontal, Liquid.Space.section)
                        .frame(minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                                .fill(Liquid.fg0)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(Liquid.Space.xxl)
        }
    }
}
