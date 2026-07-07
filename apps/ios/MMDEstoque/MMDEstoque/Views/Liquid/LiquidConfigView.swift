import SwiftUI

// MARK: - LiquidConfigView
//
// Reskin Liquid do Config: Supabase, leitor simulado, salvar, sobre.

struct LiquidConfigView: View {

    @EnvironmentObject private var rfid: RFIDManager

    @State private var supabaseUrl: String = AppConfig.shared.supabaseUrl
    @State private var supabaseKey: String = AppConfig.shared.supabaseAnonKey
    @State private var useMockReader: Bool = AppConfig.shared.useMockRFID
    @State private var showSaved = false

    var body: some View {
        ZStack {
            TechnicalGridCanvas()

            ScrollView {
                VStack(alignment: .leading, spacing: Liquid.Space.section) {
                    supabaseSection
                    rfidSection
                    saveButton
                    aboutSection
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
    }

    // MARK: Supabase

    private var supabaseSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Liquid.Space.lg) {
                Text("Supabase").liquidLabel(Liquid.accentCyan)

                field(label: "URL", text: $supabaseUrl, secure: false, keyboard: .URL)
                field(label: "API key (anon)", text: $supabaseKey, secure: true, keyboard: .default)

                HStack(spacing: Liquid.Space.sm) {
                    Circle()
                        .fill(AppConfig.shared.isSupabaseConfigured ? Liquid.accentGreen : Liquid.accentAmber)
                        .frame(width: 6, height: 6)
                    Text(AppConfig.shared.isSupabaseConfigured ? "Configurado" : "Não configurado")
                        .liquidLabel(AppConfig.shared.isSupabaseConfigured ? Liquid.accentGreen : Liquid.accentAmber)
                }
            }
        }
    }

    // MARK: RFID

    private var rfidSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Liquid.Space.lg) {
                Text("Leitor RFID").liquidLabel(Liquid.accentViolet)

                HStack {
                    Text("Leitor simulado").liquidBody().foregroundStyle(Liquid.fg0)
                    Spacer()
                    Toggle("", isOn: $useMockReader)
                        .labelsHidden()
                        .tint(Liquid.accentCyan)
                }

                Divider().overlay(Liquid.glassBorder)

                row(label: "Modo ativo", value: rfid.runtimeModeText)
                row(label: "Conexão", value: connectionLabel, valueColor: connectionColor)
            }
        }
    }

    // MARK: Save

    private var saveButton: some View {
        Button { save() } label: {
            Text("Salvar")
                .font(.liquidMono(14, weight: .medium))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(hasChanges ? Liquid.bg0 : Liquid.fg3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Liquid.Space.lg)
                .background {
                    let shape = RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous)
                    if hasChanges {
                        shape.fill(Liquid.accentCyan).liquidGlow(Liquid.accentCyan, radius: 16, opacity: 0.4)
                    } else {
                        shape.fill(Liquid.glassBg).overlay(shape.strokeBorder(Liquid.glassBorder, lineWidth: 1))
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(!hasChanges)
    }

    // MARK: About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            Text("Sobre").liquidLabel()
            row(label: "Versão", value: "1.1.0 (Wave 1)")
            row(label: "Build", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-")
        }
        .padding(.horizontal, Liquid.Space.xs)
    }

    // MARK: Reusable

    private func field(label: String, text: Binding<String>, secure: Bool, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: Liquid.Space.xs) {
            Text(label).liquidLabel(Liquid.fg2)
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

    private func row(label: String, value: String, valueColor: Color = Liquid.fg1) -> some View {
        HStack {
            Text(label).liquidBody().foregroundStyle(Liquid.fg2)
            Spacer()
            Text(value).liquidMonoData(12, color: valueColor)
        }
    }

    private var savedToast: some View {
        Text("Salvo")
            .font(.liquidMono(13, weight: .medium))
            .textCase(.uppercase)
            .tracking(1.5)
            .foregroundStyle(Liquid.bg0)
            .padding(.horizontal, Liquid.Space.xxl)
            .padding(.vertical, Liquid.Space.md)
            .background(Capsule().fill(Liquid.accentGreen))
            .padding(.bottom, Liquid.Space.section)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Logic

    private var hasChanges: Bool {
        supabaseUrl != AppConfig.shared.supabaseUrl
            || supabaseKey != AppConfig.shared.supabaseAnonKey
            || useMockReader != AppConfig.shared.useMockRFID
    }

    private func save() {
        AppConfig.shared.save(supabaseUrl: supabaseUrl, anonKey: supabaseKey, useMockRFID: useMockReader)
        rfid.configure(useMock: useMockReader)
        withAnimation(Liquid.Motion.default) { showSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(Liquid.Motion.default) { showSaved = false }
        }
    }

    private var connectionLabel: String {
        switch rfid.connectionState {
        case .disconnected: return "Desconectado"
        case .discovering:  return "Buscando"
        case .connecting:   return "Conectando"
        case .connected(let info): return info.name
        case .error:        return "Erro"
        }
    }

    private var connectionColor: Color {
        switch rfid.connectionState {
        case .connected:                return Liquid.accentGreen
        case .discovering, .connecting: return Liquid.accentAmber
        case .disconnected, .error:     return Liquid.accentRed
        }
    }
}
