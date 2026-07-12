import SwiftUI

// MARK: - ProjectsListView

/// List of active projects (CONFIRMADO, EM_CAMPO).
/// Nothing Design System: dark background, Space Grotesk body, Space Mono labels.
struct ProjectsListView: View {

    @EnvironmentObject private var apiClient: APIClient

    @State private var projects: [Project] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && projects.isEmpty {
                loadingState
            } else if projects.isEmpty {
                emptyState
            } else {
                projectList
            }
        }
        .background(Color.ndBlack)
        .navigationTitle("Projetos")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadProjects() }
        .refreshable { await loadProjects() }
    }

    // MARK: - Project List

    private var projectList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Section label
                HStack {
                    Text("PROJETOS ATIVOS")
                        .ndLabelSmall()
                    Spacer()
                }
                .padding(.horizontal, NDSpacing.medium)
                .padding(.vertical, NDSpacing.compact)

                // 1px separator
                Rectangle()
                    .fill(Color.ndBorder)
                    .frame(height: 1)

                LazyVStack(spacing: 0) {
                    ForEach(projects) { project in
                        NavigationLink(value: project) {
                            projectRow(project)
                        }
                        .buttonStyle(.plain)

                        Rectangle()
                            .fill(Color.ndBorder)
                            .frame(height: 1)
                            .padding(.leading, NDSpacing.medium)
                    }
                }
            }
        }
    }

    // MARK: - Project Row

    private func projectRow(_ project: Project) -> some View {
        HStack(spacing: NDSpacing.compact) {
            VStack(alignment: .leading, spacing: NDSpacing.tight) {
                // Project name
                Text(project.nome)
                    .font(.ndBody)
                    .foregroundStyle(Color.ndTextPrimary)
                    .lineLimit(1)

                // Client
                if let cliente = project.cliente {
                    Text(cliente.uppercased())
                        .font(.spaceMono(11))
                        .tracking(11 * 0.08)
                        .foregroundStyle(Color.ndTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: NDSpacing.tight) {
                // Status badge
                StatusBadge(
                    text: project.status.displayName,
                    color: project.status.color
                )

                // Date
                if let data = project.dataInicioFormatado {
                    Text(data.uppercased())
                        .font(.spaceMono(9))
                        .tracking(9 * 0.08)
                        .foregroundStyle(Color.ndTextDisabled)
                }
            }
        }
        .padding(.horizontal, NDSpacing.medium)
        .padding(.vertical, 14)
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: NDSpacing.medium) {
            Spacer()
            ProgressView()
                .tint(Color.ndTextSecondary)
            Text("CARREGANDO")
                .ndLabelSmall()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: NDSpacing.medium) {
            Spacer()
            Image(systemName: "folder")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(Color.ndTextDisabled)

            Text("Nenhum projeto ativo")
                .font(.ndBody)
                .foregroundStyle(Color.ndTextSecondary)

            Text("PROJETOS CONFIRMADOS OU EM CAMPO APARECEM AQUI")
                .ndLabelSmall()
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, NDSpacing.wide)
    }

    // MARK: - Data Loading

    private func loadProjects() async {
        isLoading = true
        error = nil

        do {
            projects = try await apiClient.fetchProjects(
                status: [.confirmado, .emCampo]
            )
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Preview

#if DEBUG
struct ProjectsListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProjectsListView()
                .environmentObject(APIClient())
        }
        .preferredColorScheme(.dark)
    }
}
#endif
