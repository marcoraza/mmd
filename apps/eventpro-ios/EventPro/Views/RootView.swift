import SwiftUI

/// Raiz da navegação. UI mínima e sem design system: a camada visual do
/// EventPro chega na fase 7 do plano de migração e substitui tudo isto.
struct RootView: View {

    @EnvironmentObject private var authService: AuthService

    var body: some View {
        if authService.isAuthenticated {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

struct MainTabView: View {

    var body: some View {
        TabView {
            NavigationStack {
                EventosListView()
            }
            .tabItem {
                Label("Eventos", systemImage: "calendar")
            }

            NavigationStack {
                VincularTagView()
            }
            .tabItem {
                Label("Etiquetar", systemImage: "tag")
            }

            NavigationStack {
                AjustesView()
            }
            .tabItem {
                Label("Ajustes", systemImage: "gearshape")
            }
        }
    }
}

// MARK: - Componentes compartilhados

/// Faixa de estado do leitor, reutilizada nos fluxos de campo.
struct ReaderStatusBar: View {

    @EnvironmentObject private var rfid: RFIDManager

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: rfid.statusIcon)
            VStack(alignment: .leading, spacing: 2) {
                Text(rfid.statusText)
                    .font(.footnote)
                Text("\(rfid.runtimeModeText) · \(rfid.tagCount) tag(s)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if rfid.isScanning {
                ProgressView()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }
}

/// Botões de leitura, usados por check-out, retorno e conferência.
struct ScanControls: View {

    @EnvironmentObject private var rfid: RFIDManager

    var body: some View {
        HStack(spacing: 12) {
            Button(rfid.isScanning ? "Parar leitura" : "Ler RFID") {
                if rfid.isScanning {
                    rfid.stopInventory()
                } else {
                    rfid.startInventory()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!rfid.isConnected)

            Button("Limpar") {
                rfid.clearTags()
            }
            .buttonStyle(.bordered)
            .disabled(rfid.tagCount == 0)
        }
    }
}

/// Mensagem de erro dispensável.
struct ErrorBanner: View {

    let message: String
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
