import SwiftUI

// MARK: - LiquidLoginView
//
// Gate de autenticação: e-mail/usuário + senha contra GoTrue.
// Cobre o app sem resetar a navegação por trás.

struct LiquidLoginView: View {

    var onAuthenticated: (() -> Void)? = nil

    @State private var identifier: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            TechnicalGridCanvas()

            VStack(spacing: 0) {
                Spacer(minLength: Liquid.Space.xxl)

                VStack(alignment: .leading, spacing: Liquid.Space.section) {
                    header
                    formCard
                }
                .padding(.horizontal, Liquid.Space.xxl)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(true)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.sm) {
            Text("MMD Estoque")
                .font(.liquidSans(28, weight: .bold))
                .foregroundStyle(Liquid.fg0)

            Text("Entre com seu usuário para operar no campo.")
                .font(.liquidSans(15, weight: .regular))
                .foregroundStyle(Liquid.fg2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Form

    private var formCard: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.lg) {
            field(
                label: "Usuário ou e-mail",
                text: $identifier,
                secure: false,
                keyboard: .emailAddress
            )
            field(
                label: "Senha",
                text: $password,
                secure: true,
                keyboard: .default
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(.liquidSans(13, weight: .medium))
                    .foregroundStyle(Liquid.accentRed)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button { Task { await signIn() } } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(Liquid.bg0)
                    } else {
                        Text("Entrar")
                            .font(.liquidSans(15, weight: .semibold))
                            .foregroundStyle(canSubmit ? Liquid.bg0 : Liquid.fg3)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background {
                    let shape = RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                    if canSubmit && !isLoading {
                        shape.fill(Liquid.fg0)
                    } else {
                        shape.fill(Liquid.bg2)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || isLoading)
        }
        .padding(Liquid.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelSurface(cornerRadius: Liquid.Radius.lg)
    }

    // MARK: Field

    private func field(
        label: String,
        text: Binding<String>,
        secure: Bool,
        keyboard: UIKeyboardType
    ) -> some View {
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
            .textContentType(secure ? .password : .username)
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

    // MARK: Logic

    private var canSubmit: Bool {
        !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
    }

    @MainActor
    private func signIn() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await AuthSessionStore.shared.signIn(
                identifier: identifier,
                password: password
            )
            onAuthenticated?()
        } catch let error as AuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
