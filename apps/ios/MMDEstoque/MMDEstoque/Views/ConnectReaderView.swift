import SwiftUI

// MARK: - ConnectReaderView

/// Entry point for the Scan tab. Shows connection status, discovered readers,
/// and provides navigation to the scanning screen once connected.
struct ConnectReaderView: View {

    @EnvironmentObject private var rfidManager: RFIDManager

    var body: some View {
        ZStack {
            // Background
            Color.ndBlack.ignoresSafeArea()
            DotGrid()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: NDSpacing.wide) {
                    statusSection
                    actionSection
                    connectedReaderCard
                    readersListSection
                }
                .padding(.horizontal, NDSpacing.section)
                .padding(.top, NDSpacing.section)
                .padding(.bottom, NDSpacing.xWide)
            }
        }
        .navigationTitle("Conectar Leitor")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: NDSpacing.medium) {
            // Connection dot
            Circle()
                .fill(statusDotColor)
                .frame(width: 5, height: 5)

            // Status icon
            Image(systemName: statusSystemImage)
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(statusDotColor)

            // Status label
            Text(statusText)
                .font(.spaceMono(11))
                .textCase(.uppercase)
                .tracking(11 * 0.08)
                .foregroundStyle(statusDotColor)

            // Error message
            if case .error(let message) = rfidManager.connectionState {
                Text(message)
                    .font(.ndBodySm)
                    .foregroundStyle(Color.ndAccent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, NDSpacing.medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, NDSpacing.section)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionSection: some View {
        switch rfidManager.connectionState {
        case .connected:
            // Disconnect button
            Button {
                rfidManager.disconnect()
            } label: {
                Text("DESCONECTAR")
                    .font(.spaceMono(13, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(13 * 0.08)
                    .foregroundStyle(Color.ndAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, NDSpacing.medium)
                    .overlay(
                        Capsule()
                            .stroke(Color.ndAccent, lineWidth: 1)
                    )
            }
            .contentShape(Capsule())

        case .discovering, .connecting:
            VStack(spacing: NDSpacing.compact) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(Color.ndTextSecondary)

                Text(rfidManager.connectionState == .discovering ? "BUSCANDO LEITORES..." : "CONECTANDO...")
                    .font(.spaceMono(9))
                    .textCase(.uppercase)
                    .tracking(9 * 0.08)
                    .foregroundStyle(Color.ndTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, NDSpacing.medium)

        case .disconnected, .error:
            Button {
                rfidManager.discoverReaders()
            } label: {
                Text("BUSCAR")
                    .font(.spaceMono(13, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(13 * 0.08)
                    .foregroundStyle(Color.ndBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, NDSpacing.medium)
                    .background(Color.ndTextDisplay)
                    .clipShape(Capsule())
            }
            .contentShape(Capsule())
        }
    }

    // MARK: - Connected Reader Card

    @ViewBuilder
    private var connectedReaderCard: some View {
        if let reader = rfidManager.connectionState.readerInfo {
            VStack(alignment: .leading, spacing: NDSpacing.medium) {
                // Header
                HStack(spacing: NDSpacing.compact) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 18, weight: .thin))
                        .foregroundStyle(Color.ndSuccess)

                    VStack(alignment: .leading, spacing: NDSpacing.tight) {
                        Text(reader.name)
                            .font(.ndBody)
                            .foregroundStyle(Color.ndTextPrimary)

                        if let serial = reader.serialNumber {
                            Text(serial)
                                .font(.spaceMono(9))
                                .foregroundStyle(Color.ndTextSecondary)
                        }
                    }

                    Spacer()

                    if let battery = reader.batteryLevel {
                        batteryIndicator(level: battery)
                    }
                }

                // Divider
                Rectangle()
                    .fill(Color.ndBorder)
                    .frame(height: 1)

                // Start scan button
                NavigationLink {
                    ScanView()
                } label: {
                    HStack(spacing: NDSpacing.base) {
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 16, weight: .thin))

                        Text("INICIAR LEITURA")
                            .font(.spaceMono(13, weight: .bold))
                            .textCase(.uppercase)
                            .tracking(13 * 0.08)
                    }
                    .foregroundStyle(Color.ndBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, NDSpacing.medium)
                    .background(Color.ndTextDisplay)
                    .clipShape(Capsule())
                }
                .contentShape(Capsule())
            }
            .padding(NDSpacing.medium)
            .background(Color.ndSurfaceRaised)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.ndBorderVisible, lineWidth: 1)
            )
        }
    }

    // MARK: - Battery Indicator

    private func batteryIndicator(level: Int) -> some View {
        HStack(spacing: NDSpacing.tight) {
            // 4 segmented blocks
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    let threshold = (index + 1) * 25
                    RoundedRectangle(cornerRadius: 1)
                        .fill(level >= threshold ? batteryColor(for: level) : Color.ndBorder)
                        .frame(width: 6, height: 10)
                }
            }

            Text("\(level)%")
                .font(.spaceMono(9))
                .foregroundStyle(batteryColor(for: level))
        }
    }

    private func batteryColor(for level: Int) -> Color {
        switch level {
        case 51...100: return Color.ndSuccess
        case 21...50:  return Color.ndWarning
        default:       return Color.ndAccent
        }
    }

    // MARK: - Discovered Readers List

    @ViewBuilder
    private var readersListSection: some View {
        if !rfidManager.discoveredReaders.isEmpty && !rfidManager.connectionState.isConnected {
            VStack(alignment: .leading, spacing: NDSpacing.compact) {
                Text("LEITORES BLUETOOTH")
                    .ndLabelSmall()
                    .padding(.leading, NDSpacing.tight)

                VStack(spacing: 0) {
                    ForEach(rfidManager.discoveredReaders) { reader in
                        readerRow(reader)

                        // Bottom border between rows
                        if reader.id != rfidManager.discoveredReaders.last?.id {
                            Rectangle()
                                .fill(Color.ndBorder)
                                .frame(height: 1)
                                .padding(.leading, NDSpacing.medium)
                        }
                    }
                }
                .background(Color.ndSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.ndBorder, lineWidth: 1)
                )
            }
        }
    }

    private func readerRow(_ reader: RFIDReaderInfo) -> some View {
        Button {
            rfidManager.connect(to: reader)
        } label: {
            HStack(spacing: NDSpacing.compact) {
                VStack(alignment: .leading, spacing: NDSpacing.tight) {
                    Text(reader.name)
                        .font(.ndBody)
                        .foregroundStyle(Color.ndTextPrimary)

                    if let serial = reader.serialNumber {
                        Text(serial)
                            .font(.spaceMono(9))
                            .foregroundStyle(Color.ndTextDisabled)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .thin))
                    .foregroundStyle(Color.ndTextDisabled)
            }
            .padding(.horizontal, NDSpacing.medium)
            .padding(.vertical, NDSpacing.medium)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status Helpers

    private var statusDotColor: Color {
        switch rfidManager.connectionState {
        case .disconnected: return Color.ndAccent
        case .discovering:  return Color.ndWarning
        case .connecting:   return Color.ndWarning
        case .connected:    return Color.ndSuccess
        case .error:        return Color.ndAccent
        }
    }

    private var statusText: String {
        switch rfidManager.connectionState {
        case .disconnected: return "DESCONECTADO"
        case .discovering:  return "BUSCANDO..."
        case .connecting:   return "CONECTANDO..."
        case .connected:    return "CONECTADO"
        case .error:        return "ERRO"
        }
    }

    private var statusSystemImage: String {
        switch rfidManager.connectionState {
        case .disconnected: return "antenna.radiowaves.left.and.right.slash"
        case .discovering:  return "magnifyingglass"
        case .connecting:   return "arrow.triangle.2.circlepath"
        case .connected:    return "antenna.radiowaves.left.and.right"
        case .error:        return "exclamationmark.triangle"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ConnectReaderView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ConnectReaderView()
                .environmentObject(RFIDManager())
                .environmentObject(APIClient())
        }
        .preferredColorScheme(.dark)
    }
}
#endif
