import SwiftUI

// MARK: - LiquidConnectReader
//
// Gate do leitor RFD40. Caustic hero (momento de conexao), status central num
// anel de vidro, busca e lista de leitores. Reskin Liquid do ConnectReaderView.

struct LiquidConnectReader: View {

    @EnvironmentObject private var rfid: RFIDManager

    var body: some View {
        ZStack {
            TechnicalGridCanvas()

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
        VStack(spacing: Liquid.Space.xl) {
            Image(systemName: rfid.statusIcon)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(dotColor)
                .frame(width: 88, height: 88)
                .background(Circle().fill(Liquid.bg1))
                .overlay(Circle().strokeBorder(Liquid.hairline, lineWidth: 1))

            VStack(spacing: Liquid.Space.xs) {
                Text(statusText)
                    .font(.liquidSans(22, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(Liquid.fg0)

                Text(subtitleText)
                    .font(.liquidSans(14, weight: .regular))
                    .foregroundStyle(Liquid.fg2)
                    .multilineTextAlignment(.center)

                if case .error(let message) = rfid.connectionState {
                    Text(message)
                        .liquidSmall()
                        .foregroundStyle(Liquid.accentRed)
                        .multilineTextAlignment(.center)
                        .padding(.top, Liquid.Space.xs)
                }
            }
        }
        .padding(.top, Liquid.Space.xl)
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
            ProgressView()
                .tint(Liquid.fg1)
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
            HStack(spacing: Liquid.Space.lg) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Liquid.accentGreen)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Liquid.bg2)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(reader.name)
                        .font(.liquidSans(16, weight: .semibold))
                        .foregroundStyle(Liquid.fg0)
                    if let serial = reader.serialNumber {
                        Text(serial).liquidMonoData(11, color: Liquid.fg3)
                    }
                }

                Spacer()

                if let battery = reader.batteryLevel {
                    HStack(spacing: Liquid.Space.xs) {
                        Image(systemName: batteryIcon(battery))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(batteryColor(battery))
                        Text("\(battery)%")
                            .liquidMonoData(13, color: Liquid.fg1)
                    }
                }
            }
            .padding(Liquid.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelSurface(cornerRadius: Liquid.Radius.lg)
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
                            .panelSurface(cornerRadius: Liquid.Radius.md)
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
            .frame(minHeight: 52)
            .background {
                let shape = RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                if filled {
                    shape.fill(Liquid.fg0)
                } else {
                    shape.fill(Liquid.bg1)
                        .overlay(shape.strokeBorder(Liquid.hairline, lineWidth: 1))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func batteryIcon(_ level: Int) -> String {
        switch level {
        case 76...100: return "battery.100percent"
        case 51...75:  return "battery.75percent"
        case 26...50:  return "battery.50percent"
        case 11...25:  return "battery.25percent"
        default:       return "battery.0percent"
        }
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
        case .disconnected:             return Liquid.fg2
        case .error:                    return Liquid.accentRed
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

    private var subtitleText: String {
        switch rfid.connectionState {
        case .disconnected: return "Ligue o RFD40 e busque leitores por perto"
        case .discovering:  return "Procurando leitores Bluetooth"
        case .connecting:   return "Estabelecendo conexão"
        case .connected:    return "Leitor pronto pra operação"
        case .error:        return "Verifique o leitor e tente de novo"
        }
    }
}
