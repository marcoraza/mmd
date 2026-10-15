import Foundation
import os.log

/// Vincular uma tag RFID a um serial.
///
/// Busca pelo endpoint `GET /api/seriais/busca` — o legado baixava o catálogo
/// inteiro e filtrava em memória, o que não escala e não é a fronteira certa.
///
/// A tag oferecida é `rfidManager.lastReadTag`, a **última lida por ordem de
/// chegada**. O legado publicava as tags ordenadas alfabeticamente e usava
/// `.last`, então a tela oferecia uma tag qualquer do lote em vez da que
/// acabou de passar no leitor.
@MainActor
final class VincularTagViewModel: ObservableObject {

    @Published var termo: String = ""
    @Published var somenteSemTag: Bool = true
    @Published private(set) var resultados: [SerialBuscaItem] = []
    @Published private(set) var total: Int = 0
    @Published private(set) var hasMore: Bool = false
    @Published private(set) var isBuscando = false
    @Published private(set) var isVinculando = false
    @Published var selecionado: SerialBuscaItem?
    @Published var error: String?
    @Published private(set) var sucesso: String?

    private let apiClient: APIClient
    private let rfidManager: RFIDManager
    private let logger = Logger(subsystem: "com.emdash.eventpro", category: "VincularTag")
    private var ultimaQuery = SerialBuscaQuery()

    init(apiClient: APIClient, rfidManager: RFIDManager) {
        self.apiClient = apiClient
        self.rfidManager = rfidManager
    }

    /// Tag que acabou de passar no leitor, já normalizada.
    var tagLida: String? { rfidManager.lastReadTag }

    var podeVincular: Bool {
        selecionado != nil && tagLida != nil && !isVinculando
    }

    func buscar() async {
        let query = SerialBuscaQuery(
            q: termo,
            semTag: somenteSemTag ? true : nil,
            limit: SerialBuscaQuery.defaultLimit,
            offset: 0
        )
        await executar(query, acumulando: false)
    }

    func carregarMais() async {
        guard hasMore, !isBuscando else { return }
        await executar(ultimaQuery.nextPage(loaded: resultados.count), acumulando: true)
    }

    private func executar(_ query: SerialBuscaQuery, acumulando: Bool) async {
        isBuscando = true
        error = nil
        defer { isBuscando = false }

        do {
            let response = try await apiClient.buscaSeriais(query)
            ultimaQuery = query
            resultados = acumulando ? resultados + response.items : response.items
            total = response.total
            hasMore = response.hasMore
        } catch {
            self.error = error.localizedDescription
            logger.error("Busca de seriais falhou: \(String(describing: error))")
        }
    }

    func vincular() async {
        guard let serial = selecionado else {
            error = "Selecione o equipamento antes de vincular."
            return
        }
        guard let tag = tagLida else {
            error = "Nenhuma tag lida. Passe a etiqueta no leitor."
            return
        }

        isVinculando = true
        error = nil
        sucesso = nil
        defer { isVinculando = false }

        do {
            try await apiClient.linkTag(serialId: serial.serialId, tagRfid: tag)
            sucesso = "\(serial.codigoInterno) vinculado à tag \(tag)."
            await buscar()
        } catch {
            // Hoje sempre cai aqui: o endpoint de vínculo ainda não tem
            // contrato (gap 4.2 da auditoria). A mensagem diz o que falta em
            // vez de fingir que gravou.
            self.error = error.localizedDescription
            logger.error("Vínculo falhou: \(String(describing: error))")
        }
    }

    func limparTagLida() {
        rfidManager.clearTags()
    }
}
