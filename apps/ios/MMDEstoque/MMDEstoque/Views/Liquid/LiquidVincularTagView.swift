import SwiftUI

// MARK: - LiquidVincularTagView
//
// Trilha Etiquetar: vincular uma tag RFID virgem a um serial existente.
// Dois passos, espelhando o mockup:
//   PASSO 1: achar o item/serial alvo (busca por codigo MMD ou nome).
//   PASSO 2: ler a tag virgem (ScanEngine, gated por leitor) e confirmar.
//
// Regua nova: canvas de luz de palco + paineis de vidro com tint. So o
// momento de capturar a tag toma emprestado o hero do ScanEngine.

struct LiquidVincularTagView: View {

    /// Atalho oportunista: tag desconhecida ja capturada no scan. Quando vem
    /// preenchida, o passo 2 ja mostra a tag detectada apos achar o item.
    var seedTag: String? = nil

    @EnvironmentObject private var rfid: RFIDManager
    @StateObject private var apiClient = APIClient()

    @State private var step: VincularStep = .findItem
    @State private var selectedSerial: SerialNumber?
    @State private var selectedEquipment: Equipment?

    var body: some View {
        ZStack {
            TechnicalGridCanvas()
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
                        },
                        seedTag: seedTag
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
        .panelSurface(cornerRadius: Liquid.Radius.md)
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
                            .font(.liquidSans(15, weight: .medium))
                            .foregroundStyle(Liquid.fg0)
                            .lineLimit(1)
                        Text(item.nome)
                            .font(.liquidSans(12, weight: .regular))
                            .foregroundStyle(Liquid.fg2)
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
        .panelSurface(cornerRadius: Liquid.Radius.lg)
    }

    @ViewBuilder
    private func serialSublist(for item: Equipment) -> some View {
        let serials = serialsByItem[item.id] ?? []
        let linkable = serials.filter { ($0.tagRfid ?? "").isEmpty }

        VStack(alignment: .leading, spacing: Liquid.Space.sm) {
            Rectangle()
                .fill(Liquid.hairline)
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
                    .foregroundStyle(Liquid.fg2)

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
            .panelSurface(cornerRadius: Liquid.Radius.md, tone: .inset)
        }
        .buttonStyle(.pressableCard)
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

struct ScanTagStep: View {

    @EnvironmentObject private var rfid: RFIDManager
    @ObservedObject var apiClient: APIClient

    let serial: SerialNumber
    var equipment: Equipment?
    let onBack: () -> Void
    var seedTag: String? = nil

    @State private var capturedTag: String?
    @State private var isLinking = false
    @State private var linkError: String?
    @State private var didLink = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if didLink {
                successState
            } else if rfid.isConnected || seedTag != nil {
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
        VStack(spacing: Liquid.Space.lg) {
            selectedSerialCard
            connector
            Spacer(minLength: Liquid.Space.lg)

            if let capturedTag {
                tagDetectedCard(capturedTag)
            } else {
                TagScanRing(reduceMotion: reduceMotion)
            }

            if let linkError {
                Text(linkError)
                    .font(.liquidSans(12, weight: .medium))
                    .foregroundStyle(Liquid.accentRed)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: Liquid.Space.lg)
            ctaRow
        }
        .padding(.horizontal, Liquid.Space.lg)
        .padding(.bottom, Liquid.Space.lg)
        .onAppear(perform: startCapture)
        .onChange(of: rfid.scannedTags) { _ in
            if capturedTag == nil, let latest = rfid.scannedTags.last {
                withAnimation(Liquid.Motion.fast) { capturedTag = latest }
            }
        }
    }

    // Conector visual serial <-> tag.
    private var connector: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(LinearGradient(colors: [Liquid.accentCyan, .clear], startPoint: .top, endPoint: .bottom))
                .frame(width: 2, height: 16)
            Text("vincular").liquidLabel(Liquid.fg3)
            Rectangle()
                .fill(LinearGradient(colors: [.clear, Liquid.accentViolet], startPoint: .top, endPoint: .bottom))
                .frame(width: 2, height: 16)
        }
    }

    private func tagDetectedCard(_ tag: String) -> some View {
        VStack(alignment: .leading, spacing: Liquid.Space.sm) {
            HStack(spacing: Liquid.Space.md) {
                Image(systemName: "wave.3.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Liquid.accentCyan)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Liquid.accentCyan.opacity(0.2)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tag detectada")
                        .font(.liquidSans(12, weight: .medium))
                        .foregroundStyle(Liquid.fg2)
                    Text(tag).liquidMonoData(12, color: Liquid.fg0).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Circle().fill(Liquid.accentGreen).frame(width: 8, height: 8)
            }
            Text("Livre pra vincular ao serial acima.")
                .font(.liquidSans(12, weight: .regular))
                .foregroundStyle(Liquid.fg2)
        }
        .padding(Liquid.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                .fill(Liquid.accentCyan.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                    .strokeBorder(Liquid.accentCyan.opacity(0.4), lineWidth: 1))
        )
    }

    private var ctaRow: some View {
        HStack(spacing: Liquid.Space.md) {
            Button {
                withAnimation(Liquid.Motion.fast) { capturedTag = nil; linkError = nil }
                rfid.clearTags()
                if rfid.isConnected { rfid.startInventory() }
            } label: {
                Text("Ler outra")
                    .font(.liquidSans(15, weight: .semibold))
                    .foregroundStyle(Liquid.fg1)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background {
                        let shape = RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                        shape.fill(Liquid.bg2)
                            .overlay(shape.strokeBorder(Liquid.hairlineStrong, lineWidth: 1))
                    }
            }
            .buttonStyle(.plain)

            Button {
                Task { await linkTag() }
            } label: {
                HStack(spacing: Liquid.Space.sm) {
                    if isLinking { ProgressView().controlSize(.small).tint(Liquid.bg0) }
                    Text("Confirmar vínculo")
                        .font(.liquidSans(15, weight: .semibold))
                }
                .foregroundStyle(capturedTag != nil ? Liquid.bg0 : Liquid.fg3)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(
                    RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                        .fill(capturedTag != nil ? Liquid.fg0 : Liquid.bg1)
                )
            }
            .buttonStyle(.plain)
            .disabled(capturedTag == nil || isLinking)
        }
    }

    private func startCapture() {
        if let seedTag, capturedTag == nil {
            capturedTag = seedTag
            return
        }
        if rfid.isConnected, !rfid.isScanning {
            rfid.startInventory()
        }
    }

    // MARK: Selected serial card (fixado no topo)

    private var selectedSerialCard: some View {
        HStack(spacing: Liquid.Space.md) {
            VStack(alignment: .leading, spacing: Liquid.Space.xxs) {
                Text("SERIAL ALVO")
                    .font(.liquidMono(10, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Liquid.fg2)
                if let nome = equipment?.displayName ?? serial.item?.displayName {
                    Text(nome)
                        .font(.liquidSans(16, weight: .semibold))
                        .foregroundStyle(Liquid.fg0)
                        .lineLimit(1)
                }
                Text(serial.codigoInterno)
                    .liquidMonoData(13, color: Liquid.fg2)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Liquid.accentGreen)
        }
        .padding(Liquid.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelSurface(cornerRadius: Liquid.Radius.lg)
        .padding(.horizontal, Liquid.Space.lg)
        .padding(.top, Liquid.Space.lg)
    }

    // MARK: Success state

    private var successState: some View {
        ZStack {
            TechnicalGridCanvas()

            LiquidCompletionOverlay(
                title: "Tag vinculada",
                message: "\(serial.codigoInterno) agora responde à etiqueta nova.",
                buttonLabel: "Vincular outra"
            ) {
                resetForNext()
            }
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

// MARK: - TagScanRing
//
// Ring de captura da tag com o pulse do mockup (3 aneis crescendo e sumindo,
// stagger 0.3s). Respeita Reduzir Movimento.

private struct TagScanRing: View {
    let reduceMotion: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .strokeBorder(Liquid.accentCyan.opacity(0.4 - Double(i) * 0.1), lineWidth: 1)
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulse ? 1.15 : 0.7)
                    .opacity(pulse ? 0 : 0.8)
                    .animation(
                        reduceMotion ? nil :
                            .easeOut(duration: 2).repeatForever(autoreverses: false).delay(Double(i) * 0.3),
                        value: pulse
                    )
            }

            Circle()
                .fill(RadialGradient(
                    colors: [Liquid.accentCyan.opacity(0.3), Liquid.accentCyan.opacity(0.08)],
                    center: .center, startRadius: 0, endRadius: 58))
                .overlay(Circle().strokeBorder(Liquid.accentCyan.opacity(0.6), lineWidth: 1.5))
                .frame(width: 116, height: 116)
                .overlay(
                    VStack(spacing: Liquid.Space.sm) {
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(Liquid.accentCyan)
                        Text("aproxime a tag").liquidLabel(Liquid.fg2)
                    }
                )
        }
        .frame(width: 220, height: 220)
        .onAppear { if !reduceMotion { pulse = true } }
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
                .font(.liquidMono(10, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Liquid.fg2)
            Text(title)
                .font(.liquidSans(22, weight: .semibold))
                .tracking(-0.4)
                .foregroundStyle(Liquid.fg0)
            Text(subtitle)
                .font(.liquidSans(14, weight: .regular))
                .foregroundStyle(Liquid.fg2)
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
        .panelSurface(cornerRadius: Liquid.Radius.md)
    }
}
