import SwiftUI

/// Raiz autenticada: troca de aba real na barra flutuante. Eventos e a
/// primeira tela de operacao e por isso abre por padrao.
struct HomeView: View {
    @State private var tab: Tab = .eventos

    enum Tab: Int {
        case inicio, eventos, ajustes
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .inicio: InicioView()
                case .eventos: EventsListView()
                case .ajustes: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingBar(active: $tab)
        }
        .background(EP.bg0)
    }
}

/// Casca do inicio: vira dashboard quando os numeros heroi chegarem.
struct InicioView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EP.s6) {
                VStack(alignment: .leading, spacing: EP.s1) {
                    Text("Event Pro")
                        .font(EP.screenTitle())
                        .foregroundStyle(EP.fg0)
                    Text("Operação de campo MMD")
                        .font(EP.secondary())
                        .foregroundStyle(EP.fg2)
                }
                .padding(.top, EP.s4)
            }
            .padding(.horizontal, EP.s5)
            .padding(.bottom, 96)
        }
        .background(EP.bg0)
    }
}

/// Ajustes: sessao ativa e saida.
struct SettingsView: View {
    @EnvironmentObject private var auth: AuthState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EP.s6) {
                VStack(alignment: .leading, spacing: EP.s1) {
                    Text("Ajustes")
                        .font(EP.screenTitle())
                        .foregroundStyle(EP.fg0)
                }
                .padding(.top, EP.s4)

                VStack(alignment: .leading, spacing: EP.s2) {
                    Text("SESSÃO")
                        .font(EP.sectionLabel())
                        .foregroundStyle(EP.fg2)
                    Text(auth.email ?? "sem e-mail")
                        .font(EP.mono(14))
                        .foregroundStyle(EP.fg1)
                }
                .padding(EP.s5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .epSurface(1)

                Button {
                    auth.signOut()
                } label: {
                    Text("Sair")
                        .font(EP.itemTitle())
                        .foregroundStyle(EP.fg1)
                        .frame(maxWidth: .infinity, minHeight: EP.touchMin)
                        .epSurface(2, radius: EP.r10)
                }
                .buttonStyle(EPPressStyle())
            }
            .padding(.horizontal, EP.s5)
            .padding(.bottom, 96)
        }
        .background(EP.bg0)
    }
}

/// Barra flutuante: pilula que se separa por forma e hairline, nao por cor.
/// Item ativo marcado por halo tonal de baixa saturacao.
struct FloatingBar: View {
    @Binding var active: HomeView.Tab

    private let items: [(tab: HomeView.Tab, icon: String, label: String)] = [
        (.inicio, "house.fill", "Início"),
        (.eventos, "calendar", "Eventos"),
        (.ajustes, "gearshape", "Ajustes"),
    ]

    var body: some View {
        HStack(spacing: EP.s3) {
            HStack(spacing: 0) {
                ForEach(items, id: \.tab) { item in
                    Button {
                        withAnimation(EP.snappy) { active = item.tab }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: item.icon)
                                .font(.system(size: 17, weight: .medium))
                            Text(item.label)
                                .font(EP.secondary())
                        }
                        .foregroundStyle(active == item.tab ? EP.fg0 : EP.fg2)
                        .frame(maxWidth: .infinity, minHeight: EP.touchMin + 8)
                        .background {
                            if active == item.tab {
                                RoundedRectangle(cornerRadius: EP.r16, style: .continuous)
                                    .fill(EP.selectionHalo(EP.stateInfo))
                                    .matchedGeometryEffect(id: "bar-halo", in: halo)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(EP.s1)
            .epSurface(3, radius: EP.r20 + 8)

            Button {
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(EP.bg0)
                    .frame(width: EP.touchMin + 12, height: EP.touchMin + 12)
                    .background(EP.stateInfo, in: Circle())
            }
            .buttonStyle(EPPressStyle())
        }
        .padding(.horizontal, EP.s5)
        .padding(.bottom, EP.s2)
    }

    @Namespace private var halo
}
