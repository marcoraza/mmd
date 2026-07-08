import SwiftUI

// MARK: - LiquidQRScannerSheet
//
// Fallback de QR pras camadas de validacao. Embrulha a camera (QRScanView, um
// emissor de string puro) num sheet com moldura de vidro Liquid. O codigo lido
// volta pra trilha resolver. A camera fecha o sheet ao ler um codigo.

struct LiquidQRScannerSheet: View {

    let onCode: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isActive = false

    var body: some View {
        ZStack {
            Liquid.bg0.ignoresSafeArea()

            VStack(spacing: Liquid.Space.xl) {
                header

                ZStack {
                    QRScanView(isActive: $isActive) { code in
                        onCode(code)
                        dismiss()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous))

                    RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous)
                        .strokeBorder(Liquid.accentCyan.opacity(0.55), lineWidth: 1.5)

                    VStack {
                        Text("Aponte pro QR code")
                            .font(.liquidSans(13, weight: .medium))
                            .foregroundStyle(Liquid.fg0)
                            .padding(.horizontal, Liquid.Space.lg)
                            .padding(.vertical, Liquid.Space.sm)
                            .background(Capsule().fill(Liquid.bg0.opacity(0.75)))
                            .padding(.top, Liquid.Space.lg)
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .padding(.horizontal, Liquid.Space.xxl)

                Spacer()
            }
            .padding(.top, Liquid.Space.section)
        }
        .onAppear { isActive = true }
        .onDisappear { isActive = false }
    }

    private var header: some View {
        HStack {
            Text("Ler QR code")
                .font(.liquidSans(20, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(Liquid.fg0)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Liquid.fg1)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Liquid.bg2))
            }
            .accessibilityLabel("Fechar")
        }
        .padding(.horizontal, Liquid.Space.xxl)
    }
}
