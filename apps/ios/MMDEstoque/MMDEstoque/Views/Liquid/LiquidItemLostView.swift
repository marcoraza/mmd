import SwiftUI

// MARK: - LiquidItemLostView
//
// Item nao encontrado: busca por sinal (geiger de RFID). Header de alerta,
// ultima leitura, medidor de forca de sinal que pulsa (fica mais forte perto),
// e as acoes (marcar perdido, substituir, iniciar busca). Porte do mockup
// ItemLost.
//
// MOCK: a forca de sinal e simulada (nao ha proximidade RF real ainda). O dBm
// e os textos sao de exemplo ate a busca por sinal entrar de verdade.

struct LiquidItemLostView: View {

    let serial: SerialNumber

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var nome: String { serial.item?.displayName ?? serial.item?.nome ?? "Unidade" }

    var body: some View {
        ZStack {
            CausticBackground(intensity: .work)
            // tom de alerta vermelho por cima do caustic
            RadialGradient(colors: [Liquid.accentRed.opacity(0.18), .clear],
                           center: .top, startRadius: 0, endRadius: 360)
                .ignoresSafeArea()
                .blendMode(.screen)

            ScrollView {
                VStack(alignment: .leading, spacing: Liquid.Space.lg) {
                    header
                    lastSeenCard
                    beaconSearch
                    actions
                    cta
                }
                .padding(Liquid.Space.lg)
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
                .liquidLabel(Liquid.accentRed)
            Text(nome).liquidTitle()
            Text("\(serial.codigoInterno), esperado no Casamento Santos")
                .liquidMonoData(12, color: Liquid.fg2)
        }
        .padding(.top, Liquid.Space.sm)
    }

    // MARK: Ultima leitura

    private var lastSeenCard: some View {
        GlassCard(strong: true) {
            VStack(alignment: .leading, spacing: Liquid.Space.sm) {
                Text("Última leitura").liquidLabel()
                Text(serial.localizacao ?? "Galpão A, Prateleira 12")
                    .font(.liquidSans(15, weight: .medium)).foregroundStyle(Liquid.fg0)
                Text("há 6 dias, check-in do Réveillon Copacabana").liquidSmall()
                HStack(spacing: Liquid.Space.sm) {
                    pill("Ver no mapa")
                    pill("Histórico")
                }
                .padding(.top, Liquid.Space.xs)
            }
        }
    }

    private func pill(_ label: String) -> some View {
        Text(label)
            .font(.liquidSans(11, weight: .medium))
            .foregroundStyle(Liquid.fg1)
            .padding(.horizontal, Liquid.Space.md)
            .padding(.vertical, 6)
            .background(Capsule().fill(Liquid.glassBg).overlay(Capsule().strokeBorder(Liquid.glassBorder, lineWidth: 1)))
    }

    // MARK: Busca por sinal (geiger)

    private var beaconSearch: some View {
        VStack(spacing: Liquid.Space.md) {
            Text("Busca ativa, RFID").liquidLabel(Liquid.accentRed)
            Text("Procurando a tag pelo prédio")
                .font(.liquidSans(17, weight: .medium)).foregroundStyle(Liquid.fg0)

            SignalMeter(reduceMotion: reduceMotion)
                .frame(height: 80)
                .overlay(alignment: .topTrailing) {
                    Text("-68 dBm").liquidMonoData(11, color: Liquid.accentRed)
                }

            Text("Sinal fraco, ande pelo galpão").liquidSmall().foregroundStyle(Liquid.fg1)
            Text("Fica mais forte quando você se aproxima").liquidSmall().foregroundStyle(Liquid.fg3)
        }
        .padding(Liquid.Space.xl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous)
                .fill(Liquid.accentRed.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous)
                    .strokeBorder(Liquid.accentRed.opacity(0.3), lineWidth: 1))
        )
    }

    // MARK: Acoes

    private var actions: some View {
        VStack(spacing: Liquid.Space.sm) {
            actionRow("exclamationmark.triangle", "Marcar como perdido definitivamente")
            actionRow("shippingbox", "Substituir pelo unit #0089")
        }
    }

    private func actionRow(_ icon: String, _ label: String) -> some View {
        HStack(spacing: Liquid.Space.md) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Liquid.fg2)
            Text(label).liquidBody().foregroundStyle(Liquid.fg0)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Liquid.fg3)
        }
        .padding(Liquid.Space.lg)
        .glassSurface(cornerRadius: Liquid.Radius.md)
    }

    // MARK: CTA

    private var cta: some View {
        Text("Iniciar busca no galpão")
            .font(.liquidMono(14, weight: .medium)).textCase(.uppercase).tracking(1.2)
            .foregroundStyle(Liquid.fg0)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Liquid.Space.lg)
            .background(
                RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                    .fill(Liquid.accentRed)
                    .liquidGlow(Liquid.accentRed, radius: 18, opacity: 0.4)
            )
            .padding(.top, Liquid.Space.xs)
    }
}

// MARK: - SignalMeter (geiger)
//
// 20 barras de sinal que ondulam, sugerindo a busca viva. Congela com Reduzir
// Movimento.

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
