import SwiftUI

/// Ajustes: conexão do leitor, potência de antena, servidor e conta.
struct AjustesView: View {

    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var rfid: RFIDManager

    @State private var usarMock = AppConfig.shared.useMockRFID
    @State private var potencia = Double(AppConfig.shared.antennaPowerDeciDbm)
    @State private var mostrandoServidor = false

    var body: some View {
        List {
            Section("Leitor RFID") {
                ReaderStatusBar()
                    .listRowInsets(EdgeInsets())

                Toggle("Leitor simulado", isOn: $usarMock)
                    .onChange(of: usarMock) { novo in
                        AppConfig.shared.useMockRFID = novo
                        rfid.configure(useMock: novo)
                    }

                Button("Procurar leitores") { rfid.discoverReaders() }

                ForEach(rfid.discoveredReaders) { leitor in
                    Button {
                        rfid.connect(to: leitor)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(leitor.name)
                                if let serial = leitor.serialNumber {
                                    Text(serial).font(.caption.monospaced()).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if rfid.connectedReader?.id == leitor.id {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if rfid.isConnected {
                    Button("Atualizar bateria") { rfid.refreshBattery() }
                    Button("Desconectar", role: .destructive) { rfid.disconnect() }
                }

                if let erro = rfid.lastError {
                    ErrorBanner(message: erro.errorDescription ?? "Erro no leitor.") {
                        rfid.clearError()
                    }
                }
            }

            Section {
                VStack(alignment: .leading) {
                    Text("Potência: \(String(format: "%.1f", potencia / 10)) dBm")
                        .font(.footnote)
                    Slider(
                        value: $potencia,
                        in: Double(AppConfig.minAntennaPowerDeciDbm)...Double(AppConfig.maxAntennaPowerDeciDbm),
                        step: 5
                    ) {
                        Text("Potência")
                    } onEditingChanged: { editando in
                        guard !editando else { return }
                        rfid.setAntennaPower(deciDbm: Int(potencia))
                    }
                }
            } header: {
                Text("Potência da antena")
            } footer: {
                Text("Potência alta lê o galpão inteiro e enche a conferência de extras. Para conferir um pallet por vez, use a metade da faixa ou menos.")
            }

            Section("Servidor") {
                LabeledContent("Supabase", value: AppConfig.shared.isSupabaseConfigured ? "configurado" : "faltando")
                LabeledContent("Web API", value: AppConfig.shared.isWebApiConfigured ? "configurada" : "faltando")
                Button("Editar endpoints") { mostrandoServidor = true }
            }

            Section("Conta") {
                if let email = authService.currentUserEmail {
                    LabeledContent("Usuário", value: email)
                }
                Button("Sair", role: .destructive) {
                    rfid.disconnect()
                    authService.signOut()
                }
            }

            Section("Sobre") {
                LabeledContent("Modo do leitor", value: rfid.runtimeModeText)
                LabeledContent(
                    "Versão",
                    value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
                )
            }
        }
        .navigationTitle("Ajustes")
        .sheet(isPresented: $mostrandoServidor) {
            NavigationStack { ServidorConfigView() }
        }
    }
}
