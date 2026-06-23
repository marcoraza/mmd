import SwiftUI

// MARK: - AppRoute
//
// Contrato de navegacao da Wave 1. A Moldura e dona das rotas; cada dominio
// pendura sua tela na rota correspondente. Hashable para o NavigationStack.

enum AppRoute: Hashable {
    case identificar
    case despachar
    case receber
    case etiquetar
    case config
    case conectar
}

// MARK: - LiquidRoot
//
// Raiz do app Liquid. Banner de status do leitor sempre no topo (gate de tudo:
// o scan so vive com leitor conectado) e um NavigationStack com a Home e as
// rotas dos quatro jobs.

struct LiquidRoot: View {

    @EnvironmentObject private var rfid: RFIDManager
    @State private var path = NavigationPath()

    var body: some View {
        ZStack {
            Liquid.bg0.ignoresSafeArea()

            VStack(spacing: 0) {
                ReaderStatusBar { path.append(AppRoute.conectar) }

                NavigationStack(path: $path) {
                    LiquidHome(path: $path)
                        .navigationDestination(for: AppRoute.self) { route in
                            destination(for: route)
                        }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .identificar: IdentificarFlow()
        case .despachar:   DespacharFlow()
        case .receber:     ReceberFlow()
        case .etiquetar:   EtiquetarFlow()
        case .config:      LiquidConfigView()
        case .conectar:    LiquidConnectReader()
        }
    }
}

// MARK: - ReaderStatusBar
//
// Pilula de vidro persistente: ponto colorido por estado, icone, label do
// status. Toque abre a tela de conectar. Status sempre visivel.

struct ReaderStatusBar: View {

    @EnvironmentObject private var rfid: RFIDManager
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Liquid.Space.sm) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
                    .liquidGlow(dotColor, radius: 6, opacity: 0.7)

                Image(systemName: rfid.statusIcon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(dotColor)

                Text(rfid.statusText)
                    .liquidLabel(Liquid.fg1)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Liquid.fg3)
            }
            .padding(.horizontal, Liquid.Space.lg)
            .padding(.vertical, Liquid.Space.md)
            .glassSurface(cornerRadius: Liquid.Radius.md, strong: true)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Liquid.Space.lg)
        .padding(.top, Liquid.Space.sm)
        .padding(.bottom, Liquid.Space.xs)
    }

    private var dotColor: Color {
        switch rfid.connectionState {
        case .connected:                return Liquid.accentGreen
        case .discovering, .connecting: return Liquid.accentAmber
        case .disconnected, .error:     return Liquid.accentRed
        }
    }
}

// MARK: - FlowStub
//
// Placeholder de trilha enquanto o agente de dominio nao entrega a tela real.
// Navegavel e honesto: nomeia a trilha e marca como Wave 1. Os agentes
// substituem o corpo do flow correspondente.

struct FlowStub: View {

    let title: String
    let subtitle: String
    let icon: String
    let accent: Color

    var body: some View {
        ZStack {
            CausticBackground(intensity: .work)

            GlassCard {
                VStack(spacing: Liquid.Space.lg) {
                    Image(systemName: icon)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(accent)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(accent.opacity(0.14)))
                        .liquidGlow(accent, radius: 16, opacity: 0.3)

                    Text(title)
                        .liquidH2()

                    Text(subtitle)
                        .liquidBody()
                        .multilineTextAlignment(.center)

                    Text("Wave 1, em construção")
                        .liquidLabel(accent)
                }
            }
            .padding(Liquid.Space.xxl)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
