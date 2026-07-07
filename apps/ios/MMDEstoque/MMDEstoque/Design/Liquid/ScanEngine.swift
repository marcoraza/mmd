import SwiftUI

// MARK: - ScanAction
//
// Acao primaria parametrizavel do motor. Cada trilha pluga a sua:
// Identificar -> "Resolver", Despachar -> "Confirmar saida", etc.

struct ScanAction {
    let label: String
    var isBusy: Bool = false
    var isEnabled: Bool = true
    let handler: () -> Void
}

// MARK: - ScanEngine
//
// Motor de scan visual unico, reaproveitado nas 4 trilhas. A validacao e
// camada por cima: o motor so coleta e exibe tags, a trilha decide o que
// fazer com elas via `primaryAction`.
//
// Anatomia (regua: este e o momento hero, caustic vivo):
//   - Contador hero gigante (mono), com a unidade abaixo.
//   - Lista das tags lidas, com badge NEW que desaparece em 2s.
//   - Barra inferior: limpar, fallback QR, acao primaria, e o CTA escanear.

struct ScanEngine: View {

    @EnvironmentObject private var rfid: RFIDManager

    var heroUnit: String = "TAGS"
    var emptyHint: String = "Aponte o leitor e pressione escanear"
    var primaryAction: ScanAction? = nil
    var onQRFallback: (() -> Void)? = nil

    /// Mensagem de erro vinda da trilha (resolucao, validacao).
    var errorMessage: String? = nil

    @State private var recentTags: Set<String> = []
    @State private var scanPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            TechnicalGridCanvas()

            VStack(spacing: 0) {
                heroArea
                tagList
                bottomBar
            }
        }
        .onChange(of: rfid.scannedTags) { newTags in
            markNewTags(newTags)
        }
        .onChange(of: rfid.isScanning) { scanning in
            updatePulse(scanning)
        }
        .onDisappear {
            if rfid.isScanning { rfid.stopInventory() }
        }
    }

    // MARK: - Hero

    private var heroArea: some View {
        VStack(spacing: Liquid.Space.lg) {
            Spacer(minLength: Liquid.Space.xl)

            ZStack {
                ParticleScanField(
                    tagCount: rfid.tagCount,
                    isScanning: rfid.isScanning,
                    diameter: 300
                )

                VStack(spacing: 2) {
                    Text("\(rfid.tagCount)")
                        .font(.liquidHero(76))
                        .foregroundStyle(Liquid.fg0)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: rfid.tagCount)

                    Text(heroUnit)
                        .font(.liquidMono(10, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(Liquid.fg2)
                }
            }

            Spacer(minLength: Liquid.Space.md)

            if !rfid.isScanning && rfid.tagCount == 0 {
                Text(emptyHint)
                    .liquidSmall()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Liquid.Space.section)
                    .padding(.bottom, Liquid.Space.md)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tag List

    private var tagList: some View {
        Group {
            if rfid.scannedTags.isEmpty {
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: Liquid.Space.sm) {
                        ForEach(rfid.scannedTags.reversed(), id: \.self) { tag in
                            tagRow(tag)
                        }
                    }
                    .padding(.horizontal, Liquid.Space.lg)
                    .padding(.vertical, Liquid.Space.sm)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func tagRow(_ tag: String) -> some View {
        HStack(spacing: Liquid.Space.md) {
            Image(systemName: "wave.3.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Liquid.accentCyan)

            Text(tag)
                .liquidMonoData(13, color: Liquid.fg1)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if recentTags.contains(tag) {
                Text("NEW")
                    .liquidLabel(Liquid.accentGreen)
                    .padding(.horizontal, Liquid.Space.sm)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Liquid.accentGreen.opacity(0.14)))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Liquid.Space.lg)
        .padding(.vertical, Liquid.Space.md)
        .panelSurface(cornerRadius: Liquid.Radius.md)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: Liquid.Space.md) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.liquidSans(12, weight: .medium))
                    .foregroundStyle(Liquid.accentRed)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: Liquid.Space.lg) {
                clearButton
                Spacer()
                if onQRFallback != nil { qrButton }
                if let primaryAction { primaryButton(primaryAction) }
            }

            scanButton
        }
        .padding(Liquid.Space.lg)
    }

    private var clearButton: some View {
        Button {
            rfid.clearTags()
            recentTags.removeAll()
        } label: {
            Text("Limpar")
                .font(.liquidSans(14, weight: .medium))
                .foregroundStyle(rfid.tagCount > 0 ? Liquid.fg2 : Liquid.fg3)
        }
        .disabled(rfid.tagCount == 0)
        .accessibilityLabel("Limpar tags")
    }

    private var qrButton: some View {
        Button {
            onQRFallback?()
        } label: {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(Liquid.fg1)
                .frame(width: 44, height: 44)
                .panelSurface(cornerRadius: Liquid.Radius.sm)
        }
        .accessibilityLabel("Ler QR code")
    }

    private func primaryButton(_ action: ScanAction) -> some View {
        let active = action.isEnabled && !action.isBusy
        return Button {
            action.handler()
        } label: {
            HStack(spacing: Liquid.Space.sm) {
                if action.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Liquid.fg2)
                }
                Text(action.label)
                    .font(.liquidSans(15, weight: .semibold))
            }
            .foregroundStyle(active ? Liquid.bg0 : Liquid.fg3)
            .padding(.horizontal, Liquid.Space.xxl)
            .frame(minHeight: 44)
            .background {
                let shape = RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                if active {
                    shape.fill(Liquid.fg0)
                } else {
                    shape.fill(Liquid.bg1)
                        .overlay(shape.strokeBorder(Liquid.hairline, lineWidth: 1))
                }
            }
        }
        .disabled(!action.isEnabled || action.isBusy)
    }

    private var scanButton: some View {
        Button {
            toggleScanning()
        } label: {
            HStack(spacing: Liquid.Space.sm) {
                Image(systemName: rfid.isScanning ? "stop.fill" : "dot.radiowaves.right")
                    .font(.system(size: 15, weight: .semibold))
                Text(rfid.isScanning ? "Parar" : "Escanear")
                    .font(.liquidSans(16, weight: .semibold))
            }
            .foregroundStyle(rfid.isScanning ? Liquid.fg0 : Liquid.bg0)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(scanButtonBackground)
            .scaleEffect(rfid.isScanning && scanPulse ? 1.015 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(rfid.isScanning ? "Parar leitura" : "Iniciar leitura")
    }

    @ViewBuilder
    private var scanButtonBackground: some View {
        let shape = RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
        if rfid.isScanning {
            shape
                .fill(Liquid.bg1)
                .overlay(shape.strokeBorder(Liquid.accentCyan.opacity(0.7), lineWidth: 1.5))
                .opacity(scanPulse ? 0.75 : 1.0)
        } else {
            shape.fill(Liquid.accentCyan)
        }
    }

    // MARK: - Actions

    private func toggleScanning() {
        if rfid.isScanning {
            rfid.stopInventory()
        } else {
            rfid.startInventory()
        }
    }

    private func updatePulse(_ scanning: Bool) {
        guard !reduceMotion else { scanPulse = false; return }
        if scanning {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                scanPulse = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.3)) { scanPulse = false }
        }
    }

    private func markNewTags(_ allTags: [String]) {
        let known = recentTags.union(Set(rfid.scannedTags))
        let fresh = Set(allTags).subtracting(known)
        guard !fresh.isEmpty else { return }

        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2)) {
            recentTags.formUnion(fresh)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                recentTags.subtract(fresh)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ScanEngine_Previews: PreviewProvider {
    static var previews: some View {
        ScanEngine(
            heroUnit: "TAGS",
            primaryAction: ScanAction(label: "Resolver", isEnabled: true) {},
            onQRFallback: {}
        )
        .environmentObject(RFIDManager(useMock: true))
        .preferredColorScheme(.dark)
    }
}
#endif
