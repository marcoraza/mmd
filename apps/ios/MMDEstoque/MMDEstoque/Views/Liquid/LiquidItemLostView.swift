import SwiftUI

// MARK: - LiquidItemLostView
//
// Item nao encontrado: busca por sinal (geiger de RFID). Header de alerta,
// ultima localizacao real e o medidor de sinal.
//
// Honestidade primeiro: nada de dado inventado nem botao sem handler. A
// forca de sinal e uma PREVIA simulada (nao ha leitura de RSSI no manager
// ainda) e esta rotulada como tal. Acoes de baixa/substituicao entram
// quando existir endpoint.

struct LiquidItemLostView: View {

    let serial: SerialNumber

    @EnvironmentObject private var rfid: RFIDManager
    @EnvironmentObject private var router: LiquidRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var nome: String { serial.item?.displayName ?? serial.item?.nome ?? "Unidade" }

    var body: some View {
        ZStack {
            TechnicalGridCanvas()

            // Tom de alerta: mesmo desenho da luz de palco, na cor do estado.
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Liquid.accentRed.opacity(0.14), location: 0.0),
                    .init(color: Liquid.accentRed.opacity(0.05), location: 0.45),
                    .init(color: .clear, location: 1.0),
                ]),
                center: .top,
                startRadius: 0,
                endRadius: 900
            )
            .ignoresSafeArea()
            .blendMode(.screen)

            ScrollView {
                VStack(alignment: .leading, spacing: Liquid.Space.lg) {
                    header
                    lastSeenCard
                    beaconSearch
                }
                .padding(Liquid.Space.xxl)
                .padding(.bottom, Liquid.Space.vast)
            }
        }
        .navigationTitle("Item perdido")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.xs) {
            Label("Item não encontrado", systemImage: "exclamationmark.triangle.fill")
                .font(.liquidSans(12, weight: .semibold))
                .foregroundStyle(Liquid.accentRed)

            Text(nome)
                .font(.liquidSans(24, weight: .semibold))
                .tracking(-0.4)
                .foregroundStyle(Liquid.fg0)
                .lineLimit(2)

            Text(serial.codigoInterno)
                .liquidMonoData(12, color: Liquid.fg2)
        }
        .padding(.top, Liquid.Space.sm)
    }

    // MARK: Ultima localizacao

    private var lastSeenCard: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.xs) {
            Text("Última localização")
                .liquidSection()

            Text(serial.localizacao ?? "Sem localização registrada")
                .font(.liquidSans(15, weight: .medium))
                .foregroundStyle(serial.localizacao == nil ? Liquid.fg2 : Liquid.fg0)
        }
        .padding(Liquid.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelSurface(cornerRadius: Liquid.Radius.lg)
    }

    // MARK: Busca por sinal (geiger)

    @ViewBuilder
    private var beaconSearch: some View {
        VStack(spacing: Liquid.Space.md) {
            HStack(spacing: Liquid.Space.sm) {
                Text("Busca por sinal")
                    .font(.liquidSans(17, weight: .semibold))
                    .foregroundStyle(Liquid.fg0)

                Text("PRÉVIA")
                    .font(.liquidMono(9, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Liquid.fg2)
                    .padding(.horizontal, Liquid.Space.sm)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Liquid.bg2))
            }

            if rfid.isConnected {
                SignalMeter(reduceMotion: reduceMotion)
                    .frame(height: 80)

                Text("Ande pelo galpão. As barras ficam mais fortes perto da tag.")
                    .font(.liquidSans(13, weight: .regular))
                    .foregroundStyle(Liquid.fg2)
                    .multilineTextAlignment(.center)
            } else {
                Text("Conecte o leitor pra procurar a tag pelo sinal.")
                    .font(.liquidSans(13, weight: .regular))
                    .foregroundStyle(Liquid.fg2)
                    .multilineTextAlignment(.center)

                Button { router.push(.conectar) } label: {
                    Text("Conectar leitor")
                        .font(.liquidSans(15, weight: .semibold))
                        .foregroundStyle(Liquid.bg0)
                        .padding(.horizontal, Liquid.Space.section)
                        .frame(minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                                .fill(Liquid.fg0)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Liquid.Space.xl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous)
                .fill(Liquid.accentRed.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous)
                    .strokeBorder(Liquid.accentRed.opacity(0.25), lineWidth: 1))
        )
    }
}

// MARK: - SignalMeter (geiger)
//
// 20 barras de sinal que ondulam, sugerindo a busca viva. Congela com Reduzir
// Movimento. Simulacao: vira leitura real quando o manager expor RSSI.

private struct SignalMeter: View {
    let reduceMotion: Bool
    private let bars = 20

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { tl in
            let phase = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate * 2.2
            GeometryReader { geo in
                let slot = geo.size.width / CGFloat(bars)
                HStack(alignment: .bottom, spacing: slot * 0.35) {
                    ForEach(0..<bars, id: \.self) { i in
                        let strength = max(0, 0.3 + sin(Double(i) * 0.35 + phase) * 0.5)
                        Capsule()
                            .fill(Liquid.accentRed.opacity(0.3 + strength * 0.5))
                            .frame(height: 8 + CGFloat(strength) * 60)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}
