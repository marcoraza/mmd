import SwiftUI

// MARK: - ProjectFilter
//
// Filtro da lista de projetos por trilha. Despachar olha os confirmados que
// ainda vao a campo; Receber olha os que estao em campo voltando.

enum ProjectFilter: Hashable {
    case aSair      // CONFIRMADO: prontos pra despacho
    case emCampo    // EM_CAMPO: em operacao, voltando
    case todos

    /// Status que esta trilha carrega da API.
    var statuses: [StatusProjeto] {
        switch self {
        case .aSair:   return [.confirmado]
        case .emCampo: return [.emCampo]
        case .todos:   return [.confirmado, .emCampo]
        }
    }

    var sectionLabel: String {
        switch self {
        case .aSair:   return "Prontos pra despacho"
        case .emCampo: return "Em campo"
        case .todos:   return "Eventos ativos"
        }
    }

    var emptyTitle: String {
        switch self {
        case .aSair:   return "Nenhum evento pra despachar"
        case .emCampo: return "Nenhum evento em campo"
        case .todos:   return "Nenhum evento ativo"
        }
    }

    var emptyHint: String {
        switch self {
        case .aSair:   return "Eventos confirmados aparecem aqui pra sair pra campo."
        case .emCampo: return "Eventos que saíram pra campo aparecem aqui pra receber."
        case .todos:   return "Eventos confirmados ou em campo aparecem aqui."
        }
    }
}

// MARK: - LiquidProjectsListView
//
// Lista de projetos da trilha (Despachar/Receber), reskin Liquid de
// ProjectsListView. Cada projeto e um card de vidro com nome, cliente, datas e
// badge de status. A selecao e devolvida pelo callback `onSelect`, pra trilha
// dona empurrar o proximo passo no NavigationStack da raiz.

struct LiquidProjectsListView: View {

    let filter: ProjectFilter
    var onSelect: (Project) -> Void = { _ in }

    @EnvironmentObject private var apiClient: APIClient

    @State private var projects: [Project] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        ZStack {
            TechnicalGridCanvas()

            content
        }
        .navigationTitle("Eventos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadProjects() }
        .refreshable { await loadProjects() }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if isLoading && projects.isEmpty {
            loadingState
        } else if projects.isEmpty {
            emptyState
        } else {
            projectList
        }
    }

    private var projectList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Liquid.Space.lg) {
                LiquidSectionHeader(
                    title: filter.sectionLabel,
                    trailing: "\(projects.count)"
                )
                .padding(.horizontal, Liquid.Space.xs)

                ForEach(projects) { project in
                    Button { onSelect(project) } label: {
                        projectCard(project)
                    }
                    .buttonStyle(.pressableCard)
                }
            }
            .padding(Liquid.Space.xxl)
            .padding(.bottom, 120)   // folga pra tab bar quando raiz de tab
        }
    }

    // MARK: Project Card
    //
    // Anatomia: identidade (nome + cliente + badge), metadados mono, rodape
    // com hairline e CTA na cor da trilha.

    private func projectCard(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: Liquid.Space.lg) {
            HStack(alignment: .top, spacing: Liquid.Space.md) {
                VStack(alignment: .leading, spacing: Liquid.Space.xs) {
                    Text(project.nome)
                        .font(.liquidSans(18, weight: .semibold))
                        .tracking(-0.3)
                        .foregroundStyle(Liquid.fg0)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let cliente = project.cliente {
                        Text(cliente)
                            .font(.liquidSans(13, weight: .regular))
                            .foregroundStyle(Liquid.fg2)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: Liquid.Space.sm)

                LiquidStatusBadge(projeto: project.status)
            }

            VStack(alignment: .leading, spacing: 3) {
                if let dateLine = dateLine(for: project) {
                    Label(dateLine, systemImage: "calendar")
                        .liquidMonoData(11, color: Liquid.fg2)
                        .lineLimit(1)
                }
                if let local = project.local {
                    Label(local, systemImage: "mappin.and.ellipse")
                        .liquidMonoData(11, color: Liquid.fg2)
                        .lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: Liquid.Space.md) {
                Rectangle()
                    .fill(Liquid.hairline)
                    .frame(height: 1)

                HStack {
                    Spacer()
                    Text(ctaLabel)
                        .font(.liquidSans(13, weight: .semibold))
                        .foregroundStyle(ctaTint)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ctaTint)
                }
            }
        }
        .padding(Liquid.Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelSurface(cornerRadius: Liquid.Radius.lg)
    }

    private var ctaTint: Color {
        filter == .emCampo ? Liquid.accentGreen : Liquid.accentAmber
    }

    private var ctaLabel: String {
        switch filter {
        case .aSair:   return "Conferir packing"
        case .emCampo: return "Receber"
        case .todos:   return "Abrir"
        }
    }

    private func dateLine(for project: Project) -> String? {
        switch (project.dataInicioFormatado, project.dataFimFormatado) {
        case let (inicio?, fim?): return "\(inicio) até \(fim)"
        case let (inicio?, nil):  return inicio
        case let (nil, fim?):     return fim
        default:                  return nil
        }
    }

    // MARK: States

    private var loadingState: some View {
        VStack(spacing: Liquid.Space.lg) {
            ProgressView().tint(Liquid.fg2)
            Text("Carregando")
                .font(.liquidSans(14, weight: .medium))
                .foregroundStyle(Liquid.fg2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Liquid.Space.lg) {
            Image(systemName: error == nil ? "calendar" : "exclamationmark.triangle")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(error == nil ? Liquid.fg2 : Liquid.accentAmber)
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Liquid.bg1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Liquid.hairline, lineWidth: 1)
                )

            VStack(spacing: Liquid.Space.xs) {
                Text(error == nil ? filter.emptyTitle : "Falha ao carregar")
                    .font(.liquidSans(17, weight: .semibold))
                    .foregroundStyle(Liquid.fg0)
                    .multilineTextAlignment(.center)

                Text(error ?? filter.emptyHint)
                    .font(.liquidSans(14, weight: .regular))
                    .foregroundStyle(Liquid.fg2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Liquid.Space.section)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Data

    private func loadProjects() async {
        isLoading = true
        error = nil
        do {
            projects = try await apiClient.fetchProjects(status: filter.statuses)
        } catch {
            self.error = error.localizedDescription
            projects = []
        }
        isLoading = false
    }
}

// MARK: - Preview

#if DEBUG
struct LiquidProjectsListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LiquidProjectsListView(filter: .aSair)
                .environmentObject(APIClient())
        }
        .preferredColorScheme(.dark)
    }
}
#endif
