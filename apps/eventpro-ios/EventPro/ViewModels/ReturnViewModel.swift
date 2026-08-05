import Foundation
import Combine
import os.log

// MARK: - ReturnResult

/// Resultado da conferência de uma unidade no retorno.
///
/// `.pendente` é estado **de tela**, não de payload: na finalização ele vira
/// `NAO_VOLTOU` explícito. Ver `buildReturnProjectItems()`.
enum ReturnResult: Equatable {
    case pendente
    case ok
    case problema(observacao: String, desgaste: Int)
    case naoVoltou

    var outcome: ReturnProjectOutcome {
        switch self {
        case .ok: return .ok
        case .problema: return .problema
        // Pendente na finalização é exatamente "não voltou".
        case .pendente, .naoVoltou: return .naoVoltou
        }
    }

    var isConferido: Bool {
        self != .pendente
    }
}

// MARK: - ReturnItemState

struct ReturnItemState: Identifiable, Equatable {
    let id: UUID
    let resolved: ResolvedItem
    var result: ReturnResult = .pendente
}

// MARK: - ReturnViewModel

/// Fluxo de retorno: conferir o que voltou, marcar condição e registrar.
///
/// **Cobertura total é obrigatória.** A RPC `checkin_projeto` exige que a lista
/// enviada seja exatamente o conjunto de seriais próprios `EM_CAMPO` do evento:
/// sem duplicata, sem serial de fora, sem faltante. Retorno parcial não existe.
///
/// O app legado descartava os itens pendentes com um `compactMap` e nunca
/// produzia `NAO_VOLTOU` (divergência D1 de `docs/contratos-api.md`): qualquer
/// conferência com uma unidade não devolvida falhava com "Lista de retorno não
/// bate com as unidades que saíram neste Evento", e o operador não tinha como
/// resolver pelo app. Todo o mecanismo de `retorno_pendencias` — regra central
/// do produto — era inalcançável pelo mobile.
///
/// Aqui, item pendente vira `NAO_VOLTOU` na finalização, com confirmação
/// explícita do operador (`requerConfirmacaoDePendentes`), e nunca some do
/// payload.
@MainActor
final class ReturnViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) var outboundItems: [ReturnItemState] = []
    @Published var scanMethod: MetodoScan = .rfid
    @Published private(set) var isLoading = false
    @Published private(set) var isProcessingReturn = false
    @Published private(set) var returnComplete = false
    @Published private(set) var resultado: ReturnProjectResponse?
    @Published var error: String?

    /// Serial aguardando avaliação de condição (modal aberto).
    @Published var pendingAssessmentId: UUID?

    // MARK: - Contadores

    var okCount: Int { count(where: { $0 == .ok }) }

    var problemaCount: Int {
        outboundItems.filter { if case .problema = $0.result { return true } else { return false } }.count
    }

    var naoVoltouCount: Int { count(where: { $0 == .naoVoltou }) }

    /// Itens que o operador ainda não tocou. Na finalização viram `NAO_VOLTOU`.
    var pendenteCount: Int { count(where: { $0 == .pendente }) }

    var totalItems: Int { outboundItems.count }

    var conferidosCount: Int { okCount + problemaCount + naoVoltouCount }

    private func count(where predicate: (ReturnResult) -> Bool) -> Int {
        outboundItems.filter { predicate($0.result) }.count
    }

    // MARK: - Regras de finalização

    /// Pode finalizar sempre que houver algo em campo: a cobertura total é
    /// garantida por construção, porque nenhum item some do payload.
    var canFinalize: Bool {
        !outboundItems.isEmpty && !isProcessingReturn
    }

    /// Sobrou pendente: o operador precisa confirmar que aquilo **não voltou**
    /// antes de gravar. Item pendente abre pendência em `retorno_pendencias` e
    /// segura o evento fora de `FINALIZADO`.
    var requerConfirmacaoDePendentes: Bool {
        pendenteCount > 0
    }

    /// Itens que virariam `NAO_VOLTOU` sem terem sido marcados como tal.
    var itensQueViraoNaoVoltou: [ReturnItemState] {
        outboundItems.filter { $0.result == .pendente }
    }

    /// Observação obrigatória em `PROBLEMA`: mínimo de 3 caracteres, no servidor
    /// e aqui, para o operador errar antes do round-trip.
    static func isObservacaoValida(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    // MARK: - Dependências

    let project: Project
    private let apiClient: APIClient
    private let rfidManager: RFIDManager
    private let logger = Logger(subsystem: "com.emdash.eventpro", category: "Retorno")

    private var cancellables = Set<AnyCancellable>()
    private var processedTags = Set<String>()
    private var serialIdToIndex: [UUID: Int] = [:]

    // MARK: - Init

    init(project: Project, apiClient: APIClient, rfidManager: RFIDManager) {
        self.project = project
        self.apiClient = apiClient
        self.rfidManager = rfidManager
        subscribeToTags()
    }

    // MARK: - Carga

    /// Universo do retorno: os seriais que saíram neste evento (movimentações
    /// `SAIDA`). É o mesmo conjunto que a RPC vai exigir de volta.
    func loadOutboundItems() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let movements = try await apiClient.fetchProjectMovements(projectId: project.id, tipo: .saida)
            let serialIds = Array(Set(movements.map(\.serialNumberId)))
            guard !serialIds.isEmpty else {
                replaceOutboundItems([])
                return
            }

            let serials = try await apiClient.fetchSerialsByIds(serialIds)
            let items = serials.compactMap { serial -> ReturnItemState? in
                guard let equipment = serial.item else { return nil }
                return ReturnItemState(
                    id: serial.id,
                    resolved: ResolvedItem(serialNumber: serial, equipment: equipment)
                )
            }
            replaceOutboundItems(items)
            logger.info("Retorno: \(items.count) unidades em campo")
        } catch {
            self.error = error.localizedDescription
            logger.error("Falha ao carregar unidades em campo: \(String(describing: error))")
        }
    }

    /// Substitui o universo do retorno. Usado pela carga e pelos testes, que
    /// precisam montar o cenário sem rede.
    func replaceOutboundItems(_ items: [ReturnItemState]) {
        outboundItems = items
        serialIdToIndex.removeAll()
        for (index, item) in items.enumerated() {
            serialIdToIndex[item.id] = index
        }
    }

    // MARK: - Tags

    private func subscribeToTags() {
        rfidManager.$tagReads
            .removeDuplicates()
            .sink { [weak self] reads in
                self?.processNewTags(reads)
            }
            .store(in: &cancellables)
    }

    private func processNewTags(_ reads: [RFIDTagRead]) {
        let novos = reads.filter { !processedTags.contains($0.tag) }
        guard !novos.isEmpty else { return }
        processedTags.formUnion(novos.map(\.tag))

        Task { [weak self] in
            await self?.resolveAndMatch(novos)
        }
    }

    private func resolveAndMatch(_ reads: [RFIDTagRead]) async {
        var rssi: [String: Int] = [:]
        for read in reads where read.rssi != nil {
            rssi[read.tag] = read.rssi
        }

        do {
            let result = try await apiClient.recordAndResolveRfidTags(
                tags: reads.map(\.tag),
                contexto: .retorno,
                projectId: project.id,
                reader: rfidManager.readerRequest(),
                rssiPorTag: rssi
            )
            for item in result.resolved {
                matchSerial(item.serialNumber)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - QR

    func processQRCode(_ code: String) {
        Task { [weak self] in
            guard let self else { return }
            do {
                guard let serial = try await self.apiClient.resolveQRCode(code) else { return }
                self.matchSerial(serial)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func matchSerial(_ serial: SerialNumber) {
        guard let index = serialIdToIndex[serial.id] else { return }
        guard outboundItems[index].result == .pendente else { return }
        pendingAssessmentId = serial.id
    }

    // MARK: - Avaliação de condição

    func markAsOK(serialId: UUID) {
        setResult(.ok, for: serialId)
    }

    /// Marca problema. Recusa observação curta demais, igual ao servidor.
    @discardableResult
    func markAsProblema(serialId: UUID, observacao: String, desgaste: Int) -> Bool {
        guard Self.isObservacaoValida(observacao) else {
            error = "Unidade com problema precisa de observação do Evento (mínimo 3 caracteres)."
            return false
        }
        let trimmed = observacao.trimmingCharacters(in: .whitespacesAndNewlines)
        setResult(.problema(observacao: trimmed, desgaste: Self.clampDesgaste(desgaste)), for: serialId)
        return true
    }

    /// Marca explicitamente que a unidade não voltou. Abre pendência.
    func markAsNaoVoltou(serialId: UUID) {
        setResult(.naoVoltou, for: serialId)
    }

    /// Volta o item para pendente (desfazer).
    func resetItem(serialId: UUID) {
        setResult(.pendente, for: serialId)
    }

    private func setResult(_ result: ReturnResult, for serialId: UUID) {
        guard let index = serialIdToIndex[serialId] else { return }
        outboundItems[index].result = result
        if pendingAssessmentId == serialId {
            pendingAssessmentId = nil
        }
    }

    static func clampDesgaste(_ raw: Int) -> Int {
        min(5, max(1, raw))
    }

    // MARK: - Payload

    /// Monta o corpo de `POST /api/eventos/{id}/retorno`.
    ///
    /// Invariante: `buildReturnProjectItems().count == outboundItems.count`.
    /// Nenhum item é descartado — é isso que faz a chamada passar na cobertura
    /// total exigida pela RPC (correção da divergência D1).
    func buildReturnProjectItems() -> [ReturnProjectItemRequest] {
        outboundItems.map { item in
            switch item.result {
            case .ok:
                return ReturnProjectItemRequest(
                    serialId: item.id,
                    desgaste: Self.clampDesgaste(item.resolved.serialNumber.desgaste),
                    resultado: .ok,
                    observacao: nil
                )

            case .problema(let observacao, let desgaste):
                let trimmed = observacao.trimmingCharacters(in: .whitespacesAndNewlines)
                return ReturnProjectItemRequest(
                    serialId: item.id,
                    desgaste: Self.clampDesgaste(desgaste),
                    resultado: .problema,
                    // Servidor trunca em 240; truncar aqui evita mandar lixo.
                    observacao: trimmed.isEmpty ? nil : String(trimmed.prefix(240))
                )

            case .pendente, .naoVoltou:
                return ReturnProjectItemRequest(
                    serialId: item.id,
                    desgaste: Self.clampDesgaste(item.resolved.serialNumber.desgaste),
                    resultado: .naoVoltou,
                    observacao: item.result == .pendente
                        ? "Não conferido na finalização do retorno."
                        : nil
                )
            }
        }
    }

    // MARK: - Finalizar

    /// - Parameter confirmarPendentesComoNaoVoltou: obrigatório quando existe
    ///   item pendente. Sem confirmação, a finalização é recusada em vez de
    ///   gravar `NAO_VOLTOU` nas costas do operador.
    func finalizeReturn(confirmarPendentesComoNaoVoltou: Bool = false) async {
        guard !outboundItems.isEmpty else {
            error = "Nada pra receber de volta."
            return
        }

        if requerConfirmacaoDePendentes && !confirmarPendentesComoNaoVoltou {
            error = "\(pendenteCount) unidade(s) não conferida(s). Confirme que não voltaram antes de finalizar."
            return
        }

        isProcessingReturn = true
        error = nil
        defer { isProcessingReturn = false }

        let items = buildReturnProjectItems()

        do {
            let result = try await apiClient.returnProject(
                projectId: project.id,
                metodoScan: scanMethod,
                items: items
            )
            resultado = result
            returnComplete = true
            logger.info(
                "Retorno registrado: \(self.okCount) OK, \(self.problemaCount) problema, \(items.count - self.okCount - self.problemaCount) não voltou"
            )
        } catch {
            self.error = error.localizedDescription
            logger.error("Retorno falhou: \(String(describing: error))")
        }
    }

    // MARK: - Reset

    func reset() {
        replaceOutboundItems([])
        processedTags.removeAll()
        pendingAssessmentId = nil
        returnComplete = false
        resultado = nil
        error = nil
        rfidManager.clearTags()
    }
}
