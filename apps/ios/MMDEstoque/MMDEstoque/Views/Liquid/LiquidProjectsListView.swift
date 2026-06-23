import SwiftUI

// MARK: - ProjectFilter
//
// Filtro da lista de projetos por trilha. Despachar olha os confirmados que
// ainda vao a campo; Receber olha os que estao em campo voltando.

enum ProjectFilter {
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
        case .todos:   return "Projetos ativos"
        }
    }

    var emptyTitle: String {
        switch self {
        case .aSair:   return "Nenhum projeto pra despachar"
        case .emCampo: return "Nenhum projeto em campo"
        case .todos:   return "Nenhum projeto ativo"
        }
    }

    var emptyHint: String {
        switch self {
        case .aSair:   return "Projetos confirmados aparecem aqui pra sair pra campo."
        case .emCampo: return "Projetos que saíram pra campo aparecem aqui pra receber."
        case .todos:   return "Projetos confirmados ou em campo aparecem aqui."
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
            CausticBackground(intensity: .work)

            content
        }
        .navigationTitle("Projetos")
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
                HStack {
                    Text(filter.sectionLabel).liquidLabel(Liquid.accentCyan)
                    Spacer()
                    Text("\(projects.count)")
                        .liquidMonoData(13, color: Liquid.fg2)
                }
                .padding(.horizontal, Liquid.Space.xs)

                ForEach(projects) { project in
                    Button { onSelect(project) } label: {
                        projectCard(project)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Liquid.Space.xxl)
            .padding(.bottom, Liquid.Space.vast)
        }
    }

    // MARK: Project Card

    private func projectCard(_ project: Project) -> some View {
        GlassCard(strong: true, padding: Liquid.Space.xl) {
            VStack(alignment: .leading, spacing: Liquid.Space.md) {
                HStack(alignment: .top, spacing: Liquid.Space.md) {
                    VStack(alignment: .leading, spacing: Liquid.Space.xs) {
                        Text(project.nome)
                            .liquidH3()
                            .foregroundStyle(Liquid.fg0)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if let cliente = project.cliente {
                            Text(cliente)
                                .liquidSmall()
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: Liquid.Space.sm)

                    LiquidStatusBadge(projeto: project.status)
                }

                if let dateLine = dateLine(for: project) {
                    HStack(spacing: Liquid.Space.sm) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Liquid.fg3)
                        Text(dateLine)
                            .liquidMonoData(11, color: Liquid.fg2)
                    }
                }

                if let local = project.local {
                    HStack(spacing: Liquid.Space.sm) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Liquid.fg3)
                        Text(local)
                            .liquidMonoData(11, color: Liquid.fg2)
                            .lineLimit(1)
                    }
                }

                HStack {
                    Spacer()
                    Text(ctaLabel)
                        .font(.liquidMono(11, weight: .medium))
                        .textCase(.uppercase)
                        .tracking(1.0)
                        .foregroundStyle(filter == .emCampo ? Liquid.accentGreen : Liquid.accentAmber)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(filter == .emCampo ? Liquid.accentGreen : Liquid.accentAmber)
                }
                .padding(.top, Liquid.Space.xxs)
            }
        }
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
            Text("Carregando").liquidLabel()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Liquid.Space.lg) {
            GlassCard {
                VStack(spacing: Liquid.Space.lg) {
                    Image(systemName: error == nil ? "folder" : "exclamationmark.triangle")
                        .font(.system(size: 34, weight: .thin))
                        .foregroundStyle(error == nil ? Liquid.fg3 : Liquid.accentAmber)

                    Text(error == nil ? filter.emptyTitle : "Falha ao carregar")
                        .liquidH3()
                        .multilineTextAlignment(.center)

                    Text(error ?? filter.emptyHint)
                        .liquidBody()
                        .foregroundStyle(Liquid.fg2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(Liquid.Space.xxl)
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
