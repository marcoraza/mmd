import SwiftUI

// MARK: - LiquidVincularTagView
//
// Trilha Etiquetar: vincular uma tag RFID virgem a um serial existente.
// Dois passos, espelhando o mockup:
//   PASSO 1: achar o item/serial alvo (busca por codigo MMD ou nome).
//   PASSO 2: ler a tag virgem (ScanEngine, gated por leitor) e confirmar.
//
// Reskin Liquid, dark-first, legibilidade primeiro: as telas de leitura de
// dado usam CausticBackground(.work) e GlassCard(strong: true). So o momento
// de capturar a tag toma emprestado o hero do ScanEngine.

struct LiquidVincularTagView: View {

    @EnvironmentObject private var rfid: RFIDManager
    @StateObject private var apiClient = APIClient()

    @State private var step: VincularStep = .findItem
    @State private var selectedSerial: SerialNumber?
    @State private var selectedEquipment: Equipment?

    var body: some View {
        ZStack {
            CausticBackground(intensity: .work)
                .ignoresSafeArea()

            switch step {
            case .findItem:
                FindSerialStep(apiClient: apiClient) { serial, equipment in
                    selectedSerial = serial
                    selectedEquipment = equipment
                    rfid.clearTags()
                    withAnimation(Liquid.Motion.default) { step = .scanTag }
                }
            case .scanTag:
                if let serial = selectedSerial {
                    ScanTagStep(
                        apiClient: apiClient,
                        serial: serial,
                        equipment: selectedEquipment,
                        onBack: {
                            rfid.clearTags()
                            withAnimation(Liquid.Motion.default) { step = .findItem }
                        }
                    )
                }
            }
        }
        .navigationTitle("Etiquetar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - VincularStep

private enum VincularStep {
    case findItem
    case scanTag
}

// MARK: - Passo 1: achar o serial alvo
//
// Busca client-side sobre os itens do catalogo (fetchItems), depois carrega
// os seriais do item escolhido (fetchSerialNumbers) e oferece para vincular
// os que ainda nao tem tag. Sem endpoint de busca dedicado: filtra em memoria
// por codigo MMD, nome, marca ou modelo.

private struct FindSerialStep: View {

    @ObservedObject var apiClient: APIClient
    let onSelect: (SerialNumber, Equipment) -> Void

    @State private var allItems: [Equipment] = []
    @State private var query: String = ""
    @State private var loadError: String?

    @State private var expandedItem: Equipment?
    @State private var serialsByItem: [UUID: [SerialNumber]] = [:]
    @State private var loadingSerialsFor: UUID?
    @State private var serialError: String?

    private var filteredItems: [Equipment] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return allItems }
        let needle = trimmed.lowercased()
        return allItems.filter { item in
            let haystack = [
                item.nome,
                item.marca ?? "",
                item.modelo ?? "",
                item.categoria.prefix,
                item.categoria.displayName
            ].joined(separator: " ").lowercased()
            return haystack.contains(needle)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Liquid.Space.lg) {
                StepHeader(
                    index: 1,
                    title: "Ache o item",
                    subtitle: "Busque por código MMD, nome, marca ou modelo."
                )

                searchField

                if let loadError {
                    InlineNotice(message: loadError, color: Liquid.accentRed)
                }

                if apiClient.isLoading && allItems.isEmpty {
                    loadingRow("Carregando catálogo")
                } else if filteredItems.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredItems) { item in
                        itemCard(item)
                    }
                }
            }
            .padding(Liquid.Space.xxl)
            .padding(.bottom, Liquid.Space.vast)
        }
        .task {
            await loadItems()
        }
    }

    // MARK: Search field

    private var searchField: some View {
        HStack(spacing: Liquid.Space.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Liquid.fg3)

            TextField("", text: $query, prompt: Text("Buscar item").foregroundColor(Liquid.fg3))
                .font(.liquidSans(15))
                .foregroundStyle(Liquid.fg0)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .tint(Liquid.accentCyan)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Liquid.fg3)
                }
                .accessibilityLabel("Limpar busca")
            }
        }
        .padding(.horizontal, Liquid.Space.lg)
        .padding(.vertical, Liquid.Space.md)
        .glassSurface(cornerRadius: Liquid.Radius.md, strong: true)
    }

    // MARK: Item card

    @ViewBuilder
    private func itemCard(_ item: Equipment) -> some View {
        let isExpanded = expandedItem?.id == item.id

        VStack(spacing: 0) {
            Button {
                toggle(item)
            } label: {
                HStack(spacing: Liquid.Space.md) {
                    VStack(alignment: .leading, spacing: Liquid.Space.xxs) {
                        Text(item.displayName)
                            .liquidBody()
                            .foregroundStyle(Liquid.fg0)
                            .lineLimit(1)
                        Text(item.nome)
                            .liquidSmall()
                            .lineLimit(1)
                    }

                    Spacer()

                    LiquidCategoryBadge(categoria: item.categoria)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Liquid.fg3)
                }
                .padding(Liquid.Space.lg)
            }
            .buttonStyle(.plain)

            if isExpanded {
                serialSublist(for: item)
            }
        }
        .glassSurface(cornerRadius: Liquid.Radius.lg, strong: true)
    }

    @ViewBuilder
    private func serialSublist(for item: Equipment) -> some View {
        let serials = serialsByItem[item.id] ?? []
        let linkable = serials.filter { ($0.tagRfid ?? "").isEmpty }

        VStack(alignment: .leading, spacing: Liquid.Space.sm) {
            Rectangle()
                .fill(Liquid.glassBorder)
                .frame(height: 1)
                .padding(.bottom, Liquid.Space.xs)

            if loadingSerialsFor == item.id {
                loadingRow("Carregando seriais")
            } else if let serialError, loadingSerialsFor == nil {
                InlineNotice(message: serialError, color: Liquid.accentRed)
            } else if linkable.isEmpty {
                Text("Nenhum serial sem etiqueta neste item.")
                    .liquidSmall()
                    .padding(.vertical, Liquid.Space.sm)
            } else {
                ForEach(linkable) { serial in
                    serialRow(serial, equipment: item)
                }
            }
        }
        .padding(.horizontal, Liquid.Space.lg)
        .padding(.bottom, Liquid.Space.lg)
    }

    private func serialRow(_ serial: SerialNumber, equipment: Equipment) -> some View {
        Button {
            onSelect(serial, equipment)
        } label: {
            HStack(spacing: Liquid.Space.md) {
                Image(systemName: "tag")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Liquid.accentViolet)

                Text(serial.codigoInterno)
                    .liquidMonoData(13, color: Liquid.fg1)
                    .lineLimit(1)

                Spacer()

                LiquidStatusBadge(status: serial.status)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Liquid.fg3)
            }
            .padding(.horizontal, Liquid.Space.md)
            .padding(.vertical, Liquid.Space.md)
            .glassSurface(cornerRadius: Liquid.Radius.md)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Vincular tag em \(serial.codigoInterno)")
    }

    // MARK: Helpers

    private var emptyState: some View {
        VStack(spacing: Liquid.Space.sm) {
            Image(systemName: "shippingbox")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Liquid.fg3)
            Text(query.isEmpty ? "Catálogo vazio." : "Nenhum item para a busca.")
                .liquidSmall()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Liquid.Space.xWide)
    }

    private func loadingRow(_ label: String) -> some View {
        HStack(spacing: Liquid.Space.md) {
            ProgressView().controlSize(.small).tint(Liquid.fg1)
            Text(label)
                .liquidSmall()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Liquid.Space.md)
    }

    private func toggle(_ item: Equipment) {
        if expandedItem?.id == item.id {
            withAnimation(Liquid.Motion.fast) { expandedItem = nil }
            return
        }
        withAnimation(Liquid.Motion.fast) { expandedItem = item }
        if serialsByItem[item.id] == nil {
            Task { await loadSerials(for: item) }
        }
    }

    private func loadItems() async {
        loadError = nil
        do {
            allItems = try await apiClient.fetchItems()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func loadSerials(for item: Equipment) async {
        serialError = nil
        loadingSerialsFor = item.id
        defer { loadingSerialsFor = nil }
        do {
            let serials = try await apiClient.fetchSerialNumbers(forItemId: item.id)
            serialsByItem[item.id] = serials
        } catch {
            serialError = error.localizedDescription
        }
    }
}

// MARK: - Passo 2: ler tag virgem e confirmar
//
// Mostra o serial escolhido fixado no topo, captura uma tag desconhecida via
// ScanEngine (hero, gated por leitor) e vincula. Quando o leitor esta off,
// cai pro NeedsReaderPrompt compartilhado.

private struct ScanTagStep: View {

    @EnvironmentObject private var rfid: RFIDManager
    @ObservedObject var apiClient: APIClient

    let serial: SerialNumber
    var equipment: Equipment?
    let onBack: () -> Void

    @State private var capturedTag: String?
    @State private var isLinking = false
    @State private var linkError: String?
    @State private var didLink = false

    var body: some View {
        Group {
            if didLink {
                successState
            } else if rfid.isConnected {
                scanState
            } else {
                VStack(spacing: 0) {
                    selectedSerialCard
                    NeedsReaderPrompt()
                }
            }
        }
    }

    // MARK: Scan state

    private var scanState: some View {
        VStack(spacing: 0) {
            selectedSerialCard

            ScanEngine(
                heroUnit: "TAG NOVA",
                emptyHint: "Aproxime a tag virgem e pressione escanear",
                primaryAction: ScanAction(
                    label: capturedTag == nil ? "Capturar" : "Confirmar vínculo",
                    isBusy: isLinking,
                    isEnabled: scanActionEnabled,
                    handler: handlePrimaryAction
                ),
                errorMessage: linkError
            )
            .overlay(alignment: .top) {
                if let capturedTag {
                    capturedTagBanner(capturedTag)
                        .padding(.horizontal, Liquid.Space.lg)
                        .padding(.top, Liquid.Space.sm)
                }
            }
        }
        .onChange(of: rfid.scannedTags) { _ in
            // Captura automatica da primeira tag lida enquanto nenhuma foi fixada.
            if capturedTag == nil, let latest = rfid.scannedTags.last {
                withAnimation(Liquid.Motion.fast) { capturedTag = latest }
            }
        }
    }

    private var scanActionEnabled: Bool {
        if capturedTag == nil {
            return !rfid.scannedTags.isEmpty
        }
        return !isLinking
    }

    private func handlePrimaryAction() {
        if capturedTag == nil {
            capturedTag = rfid.scannedTags.last
        } else {
            Task { await linkTag() }
        }
    }

    // MARK: Selected serial card (fixado no topo)

    private var selectedSerialCard: some View {
        GlassCard(cornerRadius: Liquid.Radius.lg, strong: true, padding: Liquid.Space.lg) {
            HStack(spacing: Liquid.Space.md) {
                VStack(alignment: .leading, spacing: Liquid.Space.xxs) {
                    Text("SERIAL ALVO")
                        .liquidLabel(Liquid.accentViolet)
                    if let nome = equipment?.displayName ?? serial.item?.displayName {
                        Text(nome)
                            .liquidH3()
                            .foregroundStyle(Liquid.fg0)
                            .lineLimit(1)
                    }
                    Text(serial.codigoInterno)
                        .liquidMonoData(13, color: Liquid.fg2)
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Liquid.accentGreen)
            }
        }
        .padding(.horizontal, Liquid.Space.lg)
        .padding(.top, Liquid.Space.lg)
    }

    // MARK: Captured tag banner

    private func capturedTagBanner(_ tag: String) -> some View {
        HStack(spacing: Liquid.Space.md) {
            Circle()
                .fill(Liquid.accentGreen)
                .frame(width: 7, height: 7)
                .liquidGlow(Liquid.accentGreen, radius: 6, opacity: 0.7)

            VStack(alignment: .leading, spacing: Liquid.Space.xxs) {
                Text("TAG DETECTADA")
                    .liquidLabel(Liquid.accentGreen)
                Text(tag)
                    .liquidMonoData(12, color: Liquid.fg1)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                withAnimation(Liquid.Motion.fast) {
                    capturedTag = nil
                    linkError = nil
                }
                rfid.clearTags()
            } label: {
                Text("Ler outra")
                    .liquidLabel(Liquid.fg2)
            }
            .accessibilityLabel("Ler outra tag")
        }
        .padding(.horizontal, Liquid.Space.lg)
        .padding(.vertical, Liquid.Space.md)
        .glassSurface(cornerRadius: Liquid.Radius.md, strong: true)
    }

    // MARK: Success state

    private var successState: some View {
        ZStack {
            CausticBackground(intensity: .work)
                .ignoresSafeArea()

            GlassCard(strong: true) {
                VStack(spacing: Liquid.Space.lg) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(Liquid.accentGreen)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(Liquid.accentGreen.opacity(0.14)))
                        .liquidGlow(Liquid.accentGreen, radius: 16, opacity: 0.3)

                    Text("Tag vinculada")
                        .liquidH2()

                    Text("\(serial.codigoInterno) agora responde à etiqueta nova.")
                        .liquidBody()
                        .multilineTextAlignment(.center)

                    if let tag = capturedTag {
                        Text(tag)
                            .liquidMonoData(12, color: Liquid.fg2)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Button {
                        resetForNext()
                    } label: {
                        Text("Vincular outra")
                            .font(.liquidMono(14, weight: .medium))
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundStyle(Liquid.bg0)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Liquid.Space.lg)
                            .background(
                                RoundedRectangle(cornerRadius: Liquid.Radius.lg, style: .continuous)
                                    .fill(Liquid.accentGreen)
                                    .liquidGlow(Liquid.accentGreen, radius: 18, opacity: 0.45)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Liquid.Space.sm)
                }
            }
            .padding(Liquid.Space.xxl)
        }
    }

    // MARK: Actions

    private func linkTag() async {
        guard let tag = capturedTag else { return }
        isLinking = true
        linkError = nil
        defer { isLinking = false }
        do {
            // TODO depende do APIClient.linkTag (Codex)
            try await apiClient.linkTag(serialId: serial.id, tagRfid: tag)
            if rfid.isScanning { rfid.stopInventory() }
            rfid.clearTags()
            withAnimation(Liquid.Motion.default) { didLink = true }
        } catch {
            linkError = error.localizedDescription
        }
    }

    private func resetForNext() {
        capturedTag = nil
        linkError = nil
        didLink = false
        rfid.clearTags()
        onBack()
    }
}

// MARK: - Shared bits

private struct StepHeader: View {
    let index: Int
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.xs) {
            Text("PASSO \(index) DE 2")
                .liquidLabel(Liquid.accentViolet)
            Text(title)
                .liquidH2()
            Text(subtitle)
                .liquidBody()
        }
    }
}

private struct InlineNotice: View {
    let message: String
    let color: Color

    var body: some View {
        HStack(spacing: Liquid.Space.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(color)
            Text(message)
                .liquidSmall()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Liquid.Space.md)
        .glassSurface(cornerRadius: Liquid.Radius.md, strong: true)
    }
}
