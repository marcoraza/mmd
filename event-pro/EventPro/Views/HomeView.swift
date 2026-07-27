import SwiftUI

/// Casca inicial: prova a fundacao (superficies, tipos, press, barra
/// flutuante) com dados de sessao reais. As telas de operacao entram aqui.
struct HomeView: View {
    @EnvironmentObject private var auth: AuthState

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: EP.s6) {
                    header

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

            FloatingBar()
        }
        .background(EP.bg0)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: EP.s1) {
            Text("Event Pro")
                .font(EP.screenTitle())
                .foregroundStyle(EP.fg0)
            Text("fundação instalada, telas de operação a caminho")
                .font(EP.secondary())
                .foregroundStyle(EP.fg2)
        }
        .padding(.top, EP.s4)
    }
}

/// Barra flutuante: pilula que se separa por forma e hairline, nao por cor.
/// Item ativo marcado por halo tonal de baixa saturacao.
struct FloatingBar: View {
    @State private var active = 0
    private let items: [(icon: String, label: String)] = [
        ("house.fill", "Início"),
        ("calendar", "Eventos"),
        ("gearshape", "Ajustes"),
    ]

    var body: some View {
        HStack(spacing: EP.s3) {
            HStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { i in
                    Button {
                        withAnimation(EP.snappy) { active = i }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: items[i].icon)
                                .font(.system(size: 17, weight: .medium))
                            Text(items[i].label)
                                .font(EP.secondary())
                        }
                        .foregroundStyle(active == i ? EP.fg0 : EP.fg2)
                        .frame(maxWidth: .infinity, minHeight: EP.touchMin + 8)
                        .background {
                            if active == i {
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
