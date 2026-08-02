import SwiftUI

// MARK: - Marcadores do mapa (paridade visual com o mockup Home 2.0)
//
// Destino: halo r11 @ 14% + disco r5 branco.
// Origem: disco r4.5 em mapBase + aro branco 2.5.
// Balão: 11px semibold, unidade "km" a 72%, fundo balao, bico 7px.

/// Pin de destino: círculo branco r5 + halo r11 a 14%.
struct DestinoPinDot: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 22, height: 22)
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
        }
        .frame(width: 22, height: 22)
        .allowsHitTesting(false)
    }
}

/// Origem no galpão: r4.5 mapBase + stroke branco 2.5.
struct GalpaoOrigemDot: View {
    var body: some View {
        Circle()
            .fill(EP.mapBase)
            .frame(width: 9, height: 9)
            .overlay(
                Circle()
                    .strokeBorder(Color.white, lineWidth: 2.5)
            )
            .frame(width: 14, height: 14)
            .allowsHitTesting(false)
    }
}

/// Balão de distância ancorado acima do pin (mockup: translate(-50%,-100%), -9px).
struct DistanciaBalao: View {
    let km: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 1) {
                Text("\(km)")
                    .font(EP.balaoTexto())
                    .monospacedDigit()
                Text("km")
                    .font(.custom("InterTight", size: 11).weight(.regular))
                    .opacity(0.72)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(EP.balao)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.26), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 5, y: 3)
            )

            // Bico 7×7 rotacionado 45°.
            Rectangle()
                .fill(EP.balao)
                .frame(width: 7, height: 7)
                .rotationEffect(.degrees(45))
                .offset(y: -4)
                .shadow(color: Color.black.opacity(0.12), radius: 1, y: 1)
        }
        .padding(.bottom, 2)
        .allowsHitTesting(false)
        .accessibilityLabel("\(km) quilômetros até o destino")
    }
}

/// Conjunto pin + balão de km (stack vertical como no mockup).
struct DestinoPinComBalao: View {
    let km: Int

    var body: some View {
        VStack(spacing: 5) {
            DistanciaBalao(km: km)
            DestinoPinDot()
        }
        // Empurra o conjunto pra cima: o centro do pin fica no ponto geográfico.
        .offset(y: -18)
        .allowsHitTesting(false)
    }
}
