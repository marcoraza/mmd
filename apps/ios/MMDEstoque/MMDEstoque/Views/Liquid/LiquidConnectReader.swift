import SwiftUI

// MARK: - LiquidConnectReader
//
// Gate do leitor RFD40. Caustic hero (momento de conexao), status central num
// anel de vidro, busca e lista de leitores. Reskin Liquid do ConnectReaderView.

struct LiquidConnectReader: View {

    @EnvironmentObject private var rfid: RFIDManager

    var body: some View {
        ZStack {
            Liquid.bg0.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Liquid.Space.section) {
                    statusHero
                    actionArea
                    connectedCard
                    readersList
                }
                .padding(Liquid.Space.xxl)
                .padding(.bottom, Liquid.Space.vast)
            }
        }
        .navigationTitle("Conectar leitor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: Status Hero

    private var statusHero: some View {
        VStack(spacing: Liquid.Space.lg) {
            ZStack {
                Circle().fill(dotColor.opacity(0.10))
                Image(systemName: rfid.statusIcon)
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(dotColor)
            }
            .frame(width: 96, height: 96)

            Text(statusText)
                .font(.liquidSans(17, weight: .semibold))
                .foregroundStyle(Liquid.fg0)

            if case .error(let message) = rfid.connectionState {
                Text(message)
                    .liquidSmall()
                    .foregroundStyle(Liquid.accentRed)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, Liquid.Space.lg)
        .frame(maxWidth: .infinity)
    }

    // MARK: Action

    @ViewBuilder
    private var actionArea: some View {
        switch rfid.connectionState {
        case .connected:
            primaryButton(label: "Desconectar", icon: "xmark.circle", tint: Liquid.accentRed, filled: false) {
                rfid.disconnect()
            }
        case .discovering, .connecting:
            HStack(spacing: Liquid.Space.md) {
                ProgressView().tint(Liquid.fg1)
                Text(statusText).liquidLabel(Liquid.fg2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Liquid.Space.lg)
        case .disconnected, .error:
            primaryButton(label: "Buscar leitores", icon: "magnifyingglass", tint: Liquid.accentCyan, filled: true) {
                rfid.discoverReaders()
            }
        }
    }

    // MARK: Connected Card

    @ViewBuilder
    private var connectedCard: some View {
        if let reader = rfid.connectionState.readerInfo {
            GlassCard(strong: true) {
                HStack(spacing: Liquid.Space.lg) {
                    Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Liquid.accentGreen)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(reader.name).liquidH3()
                        if let serial = reader.serialNumber {
                            Text(serial).liquidMonoData(11, color: Liquid.fg2)
                        }
                    }

                    Spacer()

                    if let battery = reader.batteryLevel {
                        Text("\(battery)%")
                            .liquidMonoData(13, color: batteryColor(battery))
                    }
                }
            }
        }
    }

    // MARK: Readers List

    @ViewBuilder
    private var readersList: some View {
        if !rfid.discoveredReaders.isEmpty && !rfid.connectionState.isConnected {
            VStack(alignment: .leading, spacing: Liquid.Space.md) {
                Text("Leitores encontrados").liquidSection()

                VStack(spacing: Liquid.Space.sm) {
                    ForEach(rfid.discoveredReaders) { reader in
                        Button { rfid.connect(to: reader) } label: {
                            HStack(spacing: Liquid.Space.md) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(reader.name).liquidBody().foregroundStyle(Liquid.fg0)
                                    if let serial = reader.serialNumber {
                                        Text(serial).liquidMonoData(10, color: Liquid.fg3)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Liquid.fg3)
                            }
                            .padding(.horizontal, Liquid.Space.lg)
                            .padding(.vertical, Liquid.Space.lg)
                            .glassSurface(cornerRadius: Liquid.Radius.md)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func primaryButton(
        label: String, icon: String, tint: Color, filled: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Liquid.Space.sm) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(label).font(.liquidSans(16, weight: .semibold))
            }
            .foregroundStyle(filled ? Liquid.bg0 : tint)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background {
                let shape = RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                if filled {
                    shape.fill(Liquid.fg0)
                } else {
                    shape.fill(Liquid.glassBgStrong)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func batteryColor(_ level: Int) -> Color {
        switch level {
        case 51...100: return Liquid.accentGreen
        case 21...50:  return Liquid.accentAmber
        default:       return Liquid.accentRed
        }
    }

    private var dotColor: Color {
        switch rfid.connectionState {
        case .connected:                return Liquid.accentGreen
        case .discovering, .connecting: return Liquid.accentAmber
        case .disconnected, .error:     return Liquid.accentRed
        }
    }

    private var statusText: String {
        switch rfid.connectionState {
        case .disconnected: return "Desconectado"
        case .discovering:  return "Buscando leitores"
        case .connecting:   return "Conectando"
        case .connected:    return "Conectado"
        case .error:        return "Erro de conexão"
        }
    }
}
