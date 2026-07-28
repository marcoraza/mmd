import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthState

    @State private var identifier = ""
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false

    private var canSubmit: Bool {
        !identifier.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty && !busy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text("Event Pro")
                .font(EP.screenTitle())
                .foregroundStyle(EP.fg0)
            Text("Operação de campo MMD")
                .font(EP.body())
                .foregroundStyle(EP.fg2)
                .padding(.top, EP.s1)

            VStack(spacing: EP.s4) {
                field("Usuário ou e-mail") {
                    TextField("", text: $identifier)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                field("Senha") {
                    SecureField("", text: $password)
                        .textContentType(.password)
                }

                if let error {
                    Text(error)
                        .font(EP.secondary())
                        .foregroundStyle(EP.stateCritical)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: submit) {
                    HStack {
                        if busy { ProgressView().tint(EP.bg0) }
                        Text(busy ? "Entrando" : "Entrar")
                            .font(EP.itemTitle())
                    }
                    .foregroundStyle(canSubmit ? EP.bg0 : EP.fg3)
                    .frame(maxWidth: .infinity, minHeight: EP.touchMin)
                    .background(
                        canSubmit ? EP.stateInfo : EP.bg2,
                        in: RoundedRectangle(cornerRadius: EP.r12, style: .continuous)
                    )
                }
                .buttonStyle(EPPressStyle())
                .disabled(!canSubmit)
            }
            .padding(.top, EP.s8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, EP.s6)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: EP.s2) {
            Text(label.uppercased())
                .font(EP.sectionLabel())
                .foregroundStyle(EP.fg2)
            content()
                .font(EP.mono(15))
                .foregroundStyle(EP.fg0)
                .padding(.horizontal, EP.s4)
                .frame(height: EP.touchMin + 4)
                .epSurface(2, radius: EP.r10)
        }
    }

    private func submit() {
        guard canSubmit else { return }
        busy = true
        error = nil
        Task {
            do {
                try await auth.signIn(identifier: identifier, password: password)
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}
