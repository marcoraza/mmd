import Foundation
import os.log

/// Conferência RFID: lê tags e compara com o que está alocado ao Evento.
///
/// Não muta status de serial nem de evento — isso continua sendo check-out e
/// retorno. Conferência é leitura mais telemetria, e chamadas repetidas são
/// seguras: cada uma grava um lote novo de scans e recalcula os buckets do zero.
@MainActor
final class ConferenciaViewModel: ObservableObject {

    @Published var contexto: ConferenciaContexto = .conferencia
    @Published private(set) var resultado: ConferenciaRfidResponse?
    @Published private(set) var isConferindo = false
    @Published var error: String?

    let evento: Project
    private let apiClient: APIClient
    private let rfidManager: RFIDManager
    private let logger = Logger(subsystem: "com.emdash.eventpro", category: "Conferencia")

    init(evento: Project, apiClient: APIClient, rfidManager: RFIDManager) {
        self.evento = evento
        self.apiClient = apiClient
        self.rfidManager = rfidManager
    }

    var tagsLidas: Int { rfidManager.tagReads.count }

    var podeConferir: Bool { !rfidManager.tagReads.isEmpty && !isConferindo }

    /// Faltantes sem tag vinculada: não adianta ler de novo, precisam de
    /// vínculo antes de aparecerem em qualquer conferência.
    var faltantesSemTag: [ConferenciaSerial] {
        (resultado?.faltantes ?? []).filter(\.semTagVinculada)
    }

    func conferir() async {
        guard !rfidManager.tagReads.isEmpty else {
            error = "Nenhuma tag lida. Aponte o leitor para o material e puxe o gatilho."
            return
        }

        isConferindo = true
        error = nil
        defer { isConferindo = false }

        do {
            let response = try await apiClient.conferenciaRfid(
                projectId: evento.id,
                tags: rfidManager.scannedTags,
                contexto: contexto,
                reader: rfidManager.readerRequest()
            )
            resultado = response
            let resumo = response.resumoEfetivo
            logger.info(
                "Conferência \(self.contexto.rawValue): \(resumo.confirmados)/\(resumo.esperados) confirmados, \(resumo.faltantes) faltantes, \(resumo.extras) extras"
            )
        } catch {
            self.error = error.localizedDescription
            logger.error("Conferência falhou: \(String(describing: error))")
        }
    }

    func limparLeitura() {
        rfidManager.clearTags()
        resultado = nil
        error = nil
    }
}
