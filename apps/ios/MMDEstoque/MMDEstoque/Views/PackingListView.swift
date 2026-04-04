import SwiftUI

// MARK: - PackingListView

/// Shows the packing list for a project with hero progress and validation colors.
struct PackingListView: View {

    let project: Project

    @EnvironmentObject private var apiClient: APIClient

    @State private var packingItems: [PackingListItem] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && packingItems.isEmpty {
                loadingState
            } else {
                content
            }
        }
        .background(Color.ndBlack)
        .navigationTitle("Packing List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadPackingList() }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, NDSpacing.medium)
                .padding(.vertical, NDSpacing.section)

            // 1px separator
            Rectangle()
                .fill(Color.ndBorder)
                .frame(height: 1)

            if packingItems.isEmpty {
                emptyState
            } else {
                // Item list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(packingItems) { item in
                            packingItemRow(item)

                            Rectangle()
                                .fill(Color.ndBorder)
                                .frame(height: 1)
                                .padding(.leading, NDSpacing.medium)
                        }
                    }
                }
            }

            Spacer()

            // Action button
            actionButton
                .padding(NDSpacing.medium)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: NDSpacing.compact) {
            // Project name
            Text(project.nome)
                .font(.ndHeading)
                .foregroundStyle(Color.ndTextDisplay)

            // Client
            if let cliente = project.cliente {
                Text(cliente.uppercased())
                    .font(.spaceMono(11))
                    .tracking(11 * 0.08)
                    .foregroundStyle(Color.ndTextSecondary)
            }

            // Dates
            if let inicio = project.dataInicioFormatado {
                let fim = project.dataFimFormatado ?? "—"
                Text("\(inicio.uppercased()) → \(fim.uppercased())")
                    .font(.spaceMono(9))
                    .tracking(9 * 0.08)
                    .foregroundStyle(Color.ndTextDisabled)
            }

            // Hero progress
            VStack(spacing: NDSpacing.base) {
                Text("0/\(totalExpected)")
                    .font(.displayLG)
                    .foregroundStyle(Color.ndTextDisplay)

                ProgressSegmentBar(
                    total: totalExpected,
                    filled: 0,
                    filledColor: .ndSuccess
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, NDSpacing.medium)
        }
    }

    // MARK: - Packing Item Row

    private func packingItemRow(_ item: PackingListItem) -> some View {
        HStack(spacing: NDSpacing.compact) {
            VStack(alignment: .leading, spacing: NDSpacing.tight) {
                Text(item.displayName)
                    .font(.ndBodySm)
                    .foregroundStyle(Color.ndTextPrimary)
                    .lineLimit(1)

                if let categoria = item.item?.categoria {
                    Text(categoria.displayName.uppercased())
                        .font(.spaceMono(9))
                        .tracking(9 * 0.08)
                        .foregroundStyle(categoria.color)
                }
            }

            Spacer()

            // Quantity (validation color applied here)
            Text("0/\(item.quantidade)")
                .font(.spaceMono(14))
                .foregroundStyle(Color.ndWarning)
        }
        .padding(.horizontal, NDSpacing.medium)
        .padding(.vertical, 14)
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Group {
            if project.status == .confirmado {
                NavigationLink(value: ProjectNavDestination.checkout(project)) {
                    actionButtonLabel("INICIAR CHECKOUT")
                }
            } else if project.status == .emCampo {
                NavigationLink(value: ProjectNavDestination.returnFlow(project)) {
                    actionButtonLabel("INICIAR RETORNO")
                }
            }
        }
    }

    private func actionButtonLabel(_ text: String) -> some View {
        Text(text)
            .font(.spaceMono(13, weight: .bold))
            .tracking(13 * 0.08)
            .foregroundStyle(Color.ndBlack)
            .frame(maxWidth: .infinity)
            .padding(.vertical, NDSpacing.medium)
            .background(Color.ndTextDisplay, in: Capsule())
    }

    // MARK: - States

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(Color.ndTextSecondary)
            Text("CARREGANDO PACKING LIST")
                .ndLabelSmall()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: NDSpacing.medium) {
            Spacer()
            Text("Nenhum item na packing list")
                .font(.ndBody)
                .foregroundStyle(Color.ndTextSecondary)
            Text("ADICIONE ITENS PELO PAINEL WEB")
                .ndLabelSmall()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var totalExpected: Int {
        packingItems.reduce(0) { $0 + $1.quantidade }
    }

    private func loadPackingList() async {
        isLoading = true
        do {
            packingItems = try await apiClient.fetchPackingList(projectId: project.id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Preview

#if DEBUG
struct PackingListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PackingListView(
                project: Project(
                    id: UUID(),
                    nome: "Festival de Verao",
                    cliente: "Producoes XYZ",
                    dataInicio: "2026-04-15",
                    dataFim: "2026-04-17",
                    local: "Praia do Forte",
                    status: .confirmado,
                    notas: nil,
                    createdAt: nil,
                    updatedAt: nil
                )
            )
            .environmentObject(APIClient())
        }
        .preferredColorScheme(.dark)
    }
}
#endif
