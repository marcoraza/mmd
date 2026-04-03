import SwiftUI

// MARK: - ContentView

struct ContentView: View {

    @State private var selectedTab: Tab = .scan

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            Group {
                switch selectedTab {
                case .scan:
                    ScanFlowView()
                case .projetos:
                    ProjectsPlaceholderView()
                case .config:
                    ConfigView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            tabBar
        }
        .background(Color.ndBlack)
    }

    // MARK: - Tab Enum

    private enum Tab: String, CaseIterable {
        case scan
        case projetos
        case config

        var label: String {
            switch self {
            case .scan: return "SCAN"
            case .projetos: return "PROJETOS"
            case .config: return "CONFIG"
            }
        }

        var icon: String {
            switch self {
            case .scan: return "wave.3.right"
            case .projetos: return "folder"
            case .config: return "gearshape"
            }
        }
    }

    // MARK: - Custom Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.top, NDSpacing.compact)
        .padding(.bottom, NDSpacing.section)
        .background(Color.ndBlack)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.ndBorder)
                .frame(height: 1)
        }
    }

    private func tabButton(_ tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 6) {
                // Active indicator dot
                Circle()
                    .fill(selectedTab == tab ? Color.ndAccent : Color.clear)
                    .frame(width: 3, height: 3)

                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: .thin))
                    .foregroundStyle(
                        selectedTab == tab ? Color.ndTextDisplay : Color.ndTextDisabled
                    )

                Text(tab.label)
                    .font(.spaceMono(9))
                    .textCase(.uppercase)
                    .tracking(9 * 0.08)
                    .foregroundStyle(
                        selectedTab == tab ? Color.ndTextDisplay : Color.ndTextDisabled
                    )
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
    }
}

// MARK: - ScanFlowView

/// NavigationStack wrapper that owns the scan flow:
/// ConnectReaderView -> ScanView -> ScanResultView.
struct ScanFlowView: View {

    var body: some View {
        NavigationStack {
            ConnectReaderView()
        }
    }
}

// MARK: - ProjectsPlaceholderView

struct ProjectsPlaceholderView: View {

    var body: some View {
        NavigationStack {
            VStack(spacing: NDSpacing.medium) {
                Image(systemName: "folder")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(Color.ndTextDisabled)

                Text("Projetos")
                    .font(.ndHeading)
                    .foregroundStyle(Color.ndTextPrimary)

                Text("DISPONIVEL NO SPRINT 2")
                    .font(.spaceMono(11))
                    .textCase(.uppercase)
                    .tracking(11 * 0.08)
                    .foregroundStyle(Color.ndTextSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ndBlack)
            .navigationTitle("Projetos")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - ConfigView

struct ConfigView: View {

    @EnvironmentObject private var rfidManager: RFIDManager

    @State private var supabaseUrl: String = AppConfig.shared.supabaseUrl
    @State private var supabaseKey: String = AppConfig.shared.supabaseAnonKey
    @State private var useMockReader: Bool = AppConfig.shared.useMockRFID
    @State private var showSaveConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NDSpacing.wide) {

                    // --- Supabase ---
                    supabaseSection

                    sectionDivider

                    // --- RFID ---
                    rfidSection

                    sectionDivider

                    // --- Save ---
                    saveButton

                    sectionDivider

                    // --- App Info ---
                    appInfoSection
                }
                .padding(NDSpacing.section)
            }
            .background(Color.ndBlack)
            .navigationTitle("Config")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .overlay(alignment: .bottom) {
                if showSaveConfirmation {
                    saveConfirmationToast
                }
            }
        }
    }

    // MARK: - Supabase Section

    private var supabaseSection: some View {
        VStack(alignment: .leading, spacing: NDSpacing.medium) {
            Text("SUPABASE")
                .ndLabelSmall()

            VStack(spacing: NDSpacing.compact) {
                configTextField("URL", text: $supabaseUrl, contentType: .URL, keyboard: .URL)
                configSecureField("API KEY (ANON)", text: $supabaseKey)
            }

            // Config status
            HStack(spacing: NDSpacing.base) {
                Circle()
                    .fill(AppConfig.shared.isSupabaseConfigured ? Color.ndSuccess : Color.ndWarning)
                    .frame(width: 5, height: 5)

                Text(AppConfig.shared.isSupabaseConfigured ? "CONFIGURADO" : "NAO CONFIGURADO")
                    .font(.spaceMono(9))
                    .textCase(.uppercase)
                    .tracking(9 * 0.08)
                    .foregroundStyle(
                        AppConfig.shared.isSupabaseConfigured ? Color.ndSuccess : Color.ndWarning
                    )
            }
        }
    }

    // MARK: - RFID Section

    private var rfidSection: some View {
        VStack(alignment: .leading, spacing: NDSpacing.medium) {
            Text("LEITOR RFID")
                .ndLabelSmall()

            // Mock toggle
            HStack {
                Text("Leitor simulado")
                    .font(.ndBody)
                    .foregroundStyle(Color.ndTextPrimary)

                Spacer()

                Toggle("", isOn: $useMockReader)
                    .labelsHidden()
                    .tint(Color.ndAccent)
            }
            .padding(NDSpacing.medium)
            .background(Color.ndSurfaceRaised)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.ndBorder, lineWidth: 1)
            )

            // Connection status
            HStack(spacing: NDSpacing.base) {
                Circle()
                    .fill(connectionDotColor)
                    .frame(width: 5, height: 5)

                Text(connectionLabel)
                    .font(.spaceMono(11))
                    .textCase(.uppercase)
                    .tracking(11 * 0.08)
                    .foregroundStyle(connectionDotColor)
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveConfig()
        } label: {
            Text("SALVAR")
                .font(.spaceMono(13, weight: .bold))
                .textCase(.uppercase)
                .tracking(13 * 0.08)
                .foregroundStyle(hasChanges ? Color.ndBlack : Color.ndTextDisabled)
                .frame(maxWidth: .infinity)
                .padding(.vertical, NDSpacing.medium)
                .background(hasChanges ? Color.ndTextDisplay : Color.ndSurfaceRaised)
                .clipShape(Capsule())
        }
        .disabled(!hasChanges)
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: NDSpacing.compact) {
            Text("SOBRE")
                .ndLabelSmall()

            infoRow("VERSAO", value: "1.0.0 (Sprint 1)")

            infoRow(
                "BUILD",
                value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
            )
        }
    }

    // MARK: - Reusable Form Components

    private func configTextField(
        _ label: String,
        text: Binding<String>,
        contentType: UITextContentType? = nil,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: NDSpacing.tight) {
            Text(label)
                .font(.spaceMono(9))
                .textCase(.uppercase)
                .tracking(9 * 0.08)
                .foregroundStyle(Color.ndTextSecondary)

            TextField("", text: text)
                .font(.ndBody)
                .foregroundStyle(Color.ndTextPrimary)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(NDSpacing.compact)
                .background(Color.ndSurfaceRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.ndBorder, lineWidth: 1)
                )
        }
    }

    private func configSecureField(
        _ label: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: NDSpacing.tight) {
            Text(label)
                .font(.spaceMono(9))
                .textCase(.uppercase)
                .tracking(9 * 0.08)
                .foregroundStyle(Color.ndTextSecondary)

            SecureField("", text: text)
                .font(.ndBody)
                .foregroundStyle(Color.ndTextPrimary)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(NDSpacing.compact)
                .background(Color.ndSurfaceRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.ndBorder, lineWidth: 1)
                )
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.spaceMono(12))
                .foregroundStyle(Color.ndTextSecondary)

            Spacer()

            Text(value)
                .font(.spaceMono(12))
                .foregroundStyle(Color.ndTextSecondary)
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.ndBorder)
            .frame(height: 1)
    }

    // MARK: - Connection Helpers

    private var connectionDotColor: Color {
        switch rfidManager.connectionState {
        case .disconnected: return Color.ndAccent
        case .discovering:  return Color.ndWarning
        case .connecting:   return Color.ndWarning
        case .connected:    return Color.ndSuccess
        case .error:        return Color.ndAccent
        }
    }

    private var connectionLabel: String {
        switch rfidManager.connectionState {
        case .disconnected:        return "DESCONECTADO"
        case .discovering:         return "BUSCANDO..."
        case .connecting:          return "CONECTANDO..."
        case .connected(let info): return info.name
        case .error(let msg):      return msg
        }
    }

    // MARK: - Actions

    private var hasChanges: Bool {
        supabaseUrl != AppConfig.shared.supabaseUrl
            || supabaseKey != AppConfig.shared.supabaseAnonKey
    }

    private func saveConfig() {
        AppConfig.shared.save(supabaseUrl: supabaseUrl, anonKey: supabaseKey)

        withAnimation(.easeInOut(duration: 0.3)) {
            showSaveConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showSaveConfirmation = false
            }
        }
    }

    private var saveConfirmationToast: some View {
        VStack {
            Spacer()
            Text("SALVO")
                .font(.spaceMono(11, weight: .bold))
                .textCase(.uppercase)
                .tracking(11 * 0.08)
                .foregroundStyle(Color.ndBlack)
                .padding(.horizontal, NDSpacing.section)
                .padding(.vertical, NDSpacing.compact)
                .background(Color.ndSuccess, in: Capsule())
                .padding(.bottom, NDSpacing.wide)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - ConnectionStatusBadge

/// Reusable inline badge showing connection state as a colored dot + label.
struct ConnectionStatusBadge: View {

    let state: RFIDConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)

            Text(label)
                .font(.spaceMono(11))
                .textCase(.uppercase)
                .tracking(11 * 0.08)
                .foregroundStyle(dotColor)
        }
    }

    private var dotColor: Color {
        switch state {
        case .disconnected: return Color.ndAccent
        case .discovering:  return Color.ndWarning
        case .connecting:   return Color.ndWarning
        case .connected:    return Color.ndSuccess
        case .error:        return Color.ndAccent
        }
    }

    private var label: String {
        switch state {
        case .disconnected:        return "DESCONECTADO"
        case .discovering:         return "BUSCANDO..."
        case .connecting:          return "CONECTANDO..."
        case .connected(let info): return info.name
        case .error(let msg):      return msg
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(RFIDManager())
            .environmentObject(APIClient())
            .preferredColorScheme(.dark)
    }
}
#endif
