import SwiftUI

/// Login Supabase de verdade: e-mail e senha contra o GoTrue, token no
/// Keychain. O app legado pedia um JWT colado à mão em Ajustes.
struct LoginView: View {

    @EnvironmentObject private var authService: AuthService

    @State private var email = ""
    @State private var password = ""
    @State private var mostrandoConfiguracao = false
    @State private var erro: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("E-mail", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Senha", text: $password)
                        .textContentType(.password)
                } header: {
                    Text("Entrar no EventPro")
                } footer: {
                    if !AppConfig.shared.isSupabaseConfigured {
                        Text("Configure a URL e a chave anônima do Supabase antes de entrar.")
                            .foregroundStyle(.orange)
                    }
                }

                if let erro {
                    Section {
                        ErrorBanner(message: erro) { self.erro = nil }
                    }
                }

                Section {
                    Button {
                        Task { await entrar() }
                    } label: {
                        if authService.isAuthenticating {
                            ProgressView()
                        } else {
                            Text("Entrar")
                        }
                    }
                    .disabled(
                        authService.isAuthenticating
                            || email.trimmingCharacters(in: .whitespaces).isEmpty
                            || password.isEmpty
                    )

                    Button("Configuração de servidor") {
                        mostrandoConfiguracao = true
                    }
                }
            }
            .navigationTitle("EventPro")
            .sheet(isPresented: $mostrandoConfiguracao) {
                NavigationStack {
                    ServidorConfigView()
                }
            }
        }
    }

    private func entrar() async {
        erro = nil
        do {
            try await authService.signIn(email: email, password: password)
            password = ""
        } catch {
            erro = error.localizedDescription
        }
    }
}

/// Endpoints do Supabase e da Web API. Fica fora do login porque um aparelho
/// novo precisa configurar antes de conseguir autenticar.
struct ServidorConfigView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var supabaseUrl = AppConfig.shared.supabaseUrl
    @State private var anonKey = AppConfig.shared.supabaseAnonKey
    @State private var webApiUrl = AppConfig.shared.webApiUrl

    var body: some View {
        Form {
            Section("Supabase") {
                TextField("URL", text: $supabaseUrl)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                TextField("Chave anônima", text: $anonKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                TextField("URL", text: $webApiUrl)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            } header: {
                Text("Web API")
            } footer: {
                Text("Base das rotas /api/*. Toda operação de check-out, retorno e conferência passa por aqui.")
            }
        }
        .navigationTitle("Servidor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") {
                    AppConfig.shared.save(
                        supabaseUrl: supabaseUrl,
                        anonKey: anonKey,
                        webApiUrl: webApiUrl,
                        useMockRFID: AppConfig.shared.useMockRFID
                    )
                    dismiss()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
        }
    }
}
