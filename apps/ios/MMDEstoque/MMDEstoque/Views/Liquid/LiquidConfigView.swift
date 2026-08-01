import SwiftUI

// MARK: - LiquidConfigView
//
// Reskin Liquid do Config: Supabase, leitor simulado, salvar, sobre.

struct LiquidConfigView: View {

    @EnvironmentObject private var rfid: RFIDManager
    @EnvironmentObject private var router: LiquidRouter

    @State private var supabaseUrl: String = AppConfig.shared.supabaseUrl
    @State private var supabaseKey: String = AppConfig.shared.supabaseAnonKey
    @State private var webApiUrl: String = AppConfig.shared.webApiUrl
    @State private var webApiAuthToken: String = AppConfig.shared.webApiAuthToken
    @State private var useMockReader: Bool = AppConfig.shared.useMockRFID
    @State private var showSaved = false
    @State private var showAdvanced = false
    @State private var sessionEmail: String?
    @State private var showLogin = false

    var body: some View {
        ZStack {
            TechnicalGridCanvas()

            ScrollView {
                VStack(alignment: .leading, spacing: Liquid.Space.section) {
                    sessionSection
                    readerSection
                    aboutSection
                    advancedSection
                }
                .padding(Liquid.Space.xxl)
                .padding(.bottom, 120)   // folga pra tab bar quando raiz de tab
            }
        }
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if showSaved { savedToast }
        }
        .task { await refreshSessionEmail() }
        .fullScreenCover(isPresented: $showLogin) {
            LiquidLoginView {
                showLogin = false
                Task { await refreshSessionEmail() }
            }
        }
    }

    // MARK: Conta

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            LiquidSectionHeader(title: "Conta")

            VStack(alignment: .leading, spacing: Liquid.Space.lg) {
                if let sessionEmail, !sessionEmail.isEmpty {
                    HStack(spacing: Liquid.Space.md) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Conectado como")
                                .font(.liquidSans(12, weight: .regular))
                                .foregroundStyle(Liquid.fg2)
                            Text(sessionEmail)
                                .font(.liquidSans(15, weight: .semibold))
                                .foregroundStyle(Liquid.fg0)
                                .lineLimit(1)
                        }
                        Spacer(minLength: Liquid.Space.sm)
                        Button {
                            Task { await signOut() }
                        } label: {
                            Text("Sair")
                                .font(.liquidSans(13, weight: .semibold))
                                .foregroundStyle(Liquid.accentRed)
                                .padding(.horizontal, Liquid.Space.md)
                                .frame(minHeight: 34)
                                .background(Capsule().fill(Liquid.bg2))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    HStack(spacing: Liquid.Space.md) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Sem sessão")
                                .font(.liquidSans(15, weight: .medium))
                                .foregroundStyle(Liquid.fg0)
                            Text("Entre pra acessar dados reais")
                                .font(.liquidSans(12, weight: .regular))
                                .foregroundStyle(Liquid.fg2)
                        }
                        Spacer()
                        Button { showLogin = true } label: {
                            Text("Entrar")
                                .font(.liquidSans(13, weight: .semibold))
                                .foregroundStyle(Liquid.bg0)
                                .padding(.horizontal, Liquid.Space.lg)
                                .frame(minHeight: 34)
                                .background(Capsule().fill(Liquid.fg0))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(Liquid.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelSurface(cornerRadius: Liquid.Radius.lg)
        }
    }

    // MARK: Leitor
    //
    // O unico ajuste que o operador usa de verdade: estado do RFD40 com acao
    // direta (conectar/desconectar) e o modo simulado pra trabalhar sem
    // hardware. Aplica na hora, sem botao de salvar.

    private var readerSection: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            LiquidSectionHeader(title: "Leitor RFID")

            VStack(alignment: .leading, spacing: Liquid.Space.lg) {
                HStack(spacing: Liquid.Space.md) {
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(connectionTitle)
                            .font(.liquidSans(15, weight: .semibold))
                            .foregroundStyle(Liquid.fg0)
                        Text(connectionSubtitle)
                            .font(.liquidSans(12, weight: .regular))
                            .foregroundStyle(Liquid.fg2)
                            .lineLimit(1)
                    }

                    Spacer(minLength: Liquid.Space.sm)

                    connectionButton
                }

                HStack {
                    Text("Modo ativo")
                        .font(.liquidSans(12, weight: .regular))
                        .foregroundStyle(Liquid.fg2)
                    Spacer()
                    Text(rfid.runtimeModeText.uppercased())
                        .font(.liquidMono(11, weight: .semibold))
                        .foregroundStyle(readerModeColor)
                }

                Rectangle()
                    .fill(Liquid.hairline)
                    .frame(height: 1)

                HStack(spacing: Liquid.Space.md) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Leitor simulado")
                            .font(.liquidSans(15, weight: .medium))
                            .foregroundStyle(Liquid.fg0)
                        Text("Testa o app sem o RFD40 físico")
                            .font(.liquidSans(12, weight: .regular))
                            .foregroundStyle(Liquid.fg2)
                    }

                    Spacer()

                    Toggle("", isOn: $useMockReader)
                        .labelsHidden()
                        .tint(Liquid.accentGreen)
                        .onChange(of: useMockReader) { novo in
                            applyReaderMode(novo)
                        }
                }
            }
            .padding(Liquid.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelSurface(cornerRadius: Liquid.Radius.lg)
        }
    }

    @ViewBuilder
    private var connectionButton: some View {
        switch rfid.connectionState {
        case .connected:
            Button { rfid.disconnect() } label: {
                Text("Desconectar")
                    .font(.liquidSans(13, weight: .semibold))
                    .foregroundStyle(Liquid.accentRed)
                    .padding(.horizontal, Liquid.Space.md)
                    .frame(minHeight: 34)
                    .background(Capsule().fill(Liquid.bg2))
            }
            .buttonStyle(.plain)
        case .discovering, .connecting:
            ProgressView().tint(Liquid.fg2)
        case .disconnected, .error:
            Button { router.push(.conectar) } label: {
                Text("Conectar")
                    .font(.liquidSans(13, weight: .semibold))
                    .foregroundStyle(Liquid.bg0)
                    .padding(.horizontal, Liquid.Space.lg)
                    .frame(minHeight: 34)
                    .background(Capsule().fill(Liquid.fg0))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Sobre

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            LiquidSectionHeader(title: "Sobre")

            VStack(spacing: Liquid.Space.md) {
                row(
                    label: "Versão",
                    value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
                )
                Rectangle().fill(Liquid.hairline).frame(height: 1)
                row(label: "Build", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-")
            }
            .padding(Liquid.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelSurface(cornerRadius: Liquid.Radius.lg)
        }
    }

    // MARK: Avançado
    //
    // Configuracao tecnica (servidor Supabase) fora da vista do operador:
    // fechada por padrao, so quem precisa abre.

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            LiquidSectionHeader(title: "Avançado")

            VStack(alignment: .leading, spacing: Liquid.Space.lg) {
                Button {
                    withAnimation(Liquid.Motion.default) { showAdvanced.toggle() }
                } label: {
                    HStack(spacing: Liquid.Space.md) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Servidor de dados")
                                .font(.liquidSans(15, weight: .medium))
                                .foregroundStyle(Liquid.fg0)
                            Text(AppConfig.shared.isSupabaseConfigured
                                 ? "Configurado" : "Não configurado")
                                .font(.liquidSans(12, weight: .regular))
                                .foregroundStyle(AppConfig.shared.isSupabaseConfigured
                                                 ? Liquid.fg2 : Liquid.accentAmber)
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Liquid.fg3)
                            .rotationEffect(.degrees(showAdvanced ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showAdvanced {
                    field(label: "URL do Supabase", text: $supabaseUrl, secure: false, keyboard: .URL)
                    field(label: "API key (anon)", text: $supabaseKey, secure: true, keyboard: .default)
                    field(label: "API Web URL", text: $webApiUrl, secure: false, keyboard: .URL)
                    #if DEBUG
                    field(label: "API Web token (debug)", text: $webApiAuthToken, secure: true, keyboard: .default)
                    #endif
                    saveButton
                }
            }
            .padding(Liquid.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelSurface(cornerRadius: Liquid.Radius.lg)
        }
    }

    private var saveButton: some View {
        Button { save() } label: {
            Text("Salvar")
                .font(.liquidSans(15, weight: .semibold))
                .foregroundStyle(hasChanges ? Liquid.bg0 : Liquid.fg3)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background {
                    let shape = RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                    if hasChanges {
                        shape.fill(Liquid.fg0)
                    } else {
                        shape.fill(Liquid.bg2)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(!hasChanges)
    }

    // MARK: Reusable

    private func field(label: String, text: Binding<String>, secure: Bool, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: Liquid.Space.xs) {
            Text(label)
                .font(.liquidSans(12, weight: .medium))
                .foregroundStyle(Liquid.fg2)
            Group {
                if secure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                }
            }
            .font(.liquidMono(13))
            .foregroundStyle(Liquid.fg0)
            .keyboardType(keyboard)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(Liquid.Space.md)
            .background(
                RoundedRectangle(cornerRadius: Liquid.Radius.sm, style: .continuous)
                    .fill(Liquid.bg0.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: Liquid.Radius.sm, style: .continuous)
                            .strokeBorder(Liquid.glassBorder, lineWidth: 1)
                    )
            )
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.liquidSans(14, weight: .regular))
                .foregroundStyle(Liquid.fg1)
            Spacer()
            Text(value).liquidMonoData(12, color: Liquid.fg2)
        }
    }

    private var savedToast: some View {
        Text("Salvo")
            .font(.liquidSans(14, weight: .semibold))
            .foregroundStyle(Liquid.bg0)
            .padding(.horizontal, Liquid.Space.xxl)
            .padding(.vertical, Liquid.Space.md)
            .background(Capsule().fill(Liquid.accentGreen))
            .padding(.bottom, Liquid.Space.hero)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Logic

    private var hasChanges: Bool {
        supabaseUrl != AppConfig.shared.supabaseUrl
            || supabaseKey != AppConfig.shared.supabaseAnonKey
            || webApiUrl != AppConfig.shared.webApiUrl
            || webApiAuthToken != AppConfig.shared.webApiAuthToken
    }

    /// Salva so o servidor (secao avancada). O modo do leitor aplica na hora
    /// pelo toggle.
    private func save() {
        AppConfig.shared.save(
            supabaseUrl: supabaseUrl,
            anonKey: supabaseKey,
            webApiUrl: webApiUrl,
            webApiAuthToken: webApiAuthToken,
            useMockRFID: useMockReader
        )
        rfid.configure(useMock: useMockReader)
        flashSaved()
    }

    /// Toggle do leitor simulado: persiste e reconfigura o manager na hora.
    private func applyReaderMode(_ useMock: Bool) {
        AppConfig.shared.save(
            supabaseUrl: AppConfig.shared.supabaseUrl,
            anonKey: AppConfig.shared.supabaseAnonKey,
            webApiUrl: AppConfig.shared.webApiUrl,
            webApiAuthToken: AppConfig.shared.webApiAuthToken,
            useMockRFID: useMock
        )
        rfid.configure(useMock: useMock)
        flashSaved()
    }

    private func flashSaved() {
        withAnimation(Liquid.Motion.default) { showSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(Liquid.Motion.default) { showSaved = false }
        }
    }

    @MainActor
    private func refreshSessionEmail() async {
        sessionEmail = await AuthSessionStore.shared.sessionEmail
    }

    @MainActor
    private func signOut() async {
        await AuthSessionStore.shared.signOut()
        sessionEmail = nil
        showLogin = true
    }

    private var connectionTitle: String {
        switch rfid.connectionState {
        case .disconnected: return "Sem leitor"
        case .discovering:  return "Buscando leitores"
        case .connecting:   return "Conectando"
        case .connected(let info): return info.name
        case .error:        return "Erro de conexão"
        }
    }

    private var connectionSubtitle: String {
        switch rfid.connectionState {
        case .disconnected:
            return "Conecte o RFD40 pra escanear"
        case .discovering, .connecting:
            return "Aguarde"
        case .connected(let info):
            let battery = info.batteryLevel.map { "\($0)% de bateria" }
            return battery ?? "Pronto pra operação"
        case .error(let message):
            return message
        }
    }

    private var connectionColor: Color {
        switch rfid.connectionState {
        case .connected:                return Liquid.accentGreen
        case .discovering, .connecting: return Liquid.accentAmber
        case .disconnected:             return Liquid.fg3
        case .error:                    return Liquid.accentRed
        }
    }

    private var readerModeColor: Color {
        switch rfid.runtimeMode {
        case .zebra: return Liquid.accentGreen
        case .mock: return Liquid.accentAmber
        case .zebraUnavailable: return Liquid.accentRed
        }
    }
}
