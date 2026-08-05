import Foundation
import Combine

// MARK: - Reader Info

/// Representação de leitor agnóstica de hardware. Desacoplada de qualquer SDK
/// para que o resto do app nunca importe framework de fabricante.
struct RFIDReaderInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let serialNumber: String?
    let batteryLevel: Int?  // 0-100, nil quando desconhecido

    init(id: String, name: String, serialNumber: String? = nil, batteryLevel: Int? = nil) {
        self.id = id
        self.name = name
        self.serialNumber = serialNumber
        self.batteryLevel = batteryLevel
    }

    func withBattery(_ level: Int?) -> RFIDReaderInfo {
        RFIDReaderInfo(id: id, name: name, serialNumber: serialNumber, batteryLevel: level)
    }
}

// MARK: - Tag Read

/// Uma leitura de tag. `tag` já vem normalizada (`RfidTagNormalizer`), então o
/// que o app guarda é exatamente o que o servidor vai devolver em
/// `resolved[].tag_rfid` e `unresolved[]` (divergência D2).
struct RFIDTagRead: Equatable, Hashable, Identifiable {
    /// EPC normalizado (maiúsculo, sem espaço, `:` ou `-`).
    let tag: String

    /// RSSI de pico em dBm, quando o leitor reporta. Negativo, ex.: -42.
    let rssi: Int?

    /// Instante da primeira leitura desta tag na sessão atual.
    let firstSeen: Date

    var id: String { tag }

    init(tag: String, rssi: Int? = nil, firstSeen: Date = Date()) {
        self.tag = tag
        self.rssi = rssi
        self.firstSeen = firstSeen
    }

    /// Mantém a primeira aparição, mas melhora o RSSI quando a releitura vem
    /// mais forte (menos negativa). É o valor que interessa para proximidade.
    func mergingPeak(rssi newRssi: Int?) -> RFIDTagRead {
        switch (rssi, newRssi) {
        case let (current?, new?):
            return RFIDTagRead(tag: tag, rssi: max(current, new), firstSeen: firstSeen)
        case (nil, let new?):
            return RFIDTagRead(tag: tag, rssi: new, firstSeen: firstSeen)
        default:
            return self
        }
    }
}

// MARK: - Connection State

/// Estado de conexão. **Não carrega erro**: falha vive em `lastError`, tipada
/// em `RFIDReaderError`. O legado misturava os dois num `.error(String)` e
/// qualquer tratamento virava comparação de string.
enum RFIDConnectionState: Equatable {
    case disconnected
    case discovering
    case connecting
    case connected(RFIDReaderInfo)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isBusy: Bool {
        switch self {
        case .discovering, .connecting: return true
        case .disconnected, .connected: return false
        }
    }

    var readerInfo: RFIDReaderInfo? {
        if case .connected(let info) = self { return info }
        return nil
    }
}

// MARK: - Errors

/// Erros do leitor, tipados e independentes do estado de conexão.
///
/// `sdkCode` carrega o nome da constante `SRFID_RESULT_*` que o SDK devolveu,
/// para log e suporte, sem forçar a UI a conhecer o SDK.
enum RFIDReaderError: LocalizedError, Equatable {
    /// O framework da Zebra não está disponível neste build.
    case sdkUnavailable
    /// Nenhum leitor pareado/disponível no momento da operação.
    case readerNotAvailable
    /// Ação pedida sem sessão ativa.
    case notConnected
    /// Falha ao estabelecer a sessão MFi/BTLE.
    case connectionFailed(sdkCode: String, message: String?)
    /// Falha numa operação nomeada (inventário, potência, bateria...).
    case operationFailed(operation: String, sdkCode: String, message: String?)
    /// O rádio do leitor reportou erro durante a operação.
    case radioError(message: String)
    /// Configuração recusada pelo leitor (ex.: potência fora da faixa).
    case invalidConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .sdkUnavailable:
            return "SDK Zebra indisponível neste build. O app está usando o leitor simulado."
        case .readerNotAvailable:
            return "Nenhum leitor RFID disponível. Ligue o RFD40 e confira o pareamento em Ajustes do iPhone."
        case .notConnected:
            return "Leitor RFID não conectado."
        case .connectionFailed(let code, let message):
            return "Falha ao conectar o leitor (\(code))." + (message.map { " \($0)" } ?? "")
        case .operationFailed(let operation, let code, let message):
            return "Falha em \(operation) (\(code))." + (message.map { " \($0)" } ?? "")
        case .radioError(let message):
            return "Erro de rádio do leitor: \(message)"
        case .invalidConfiguration(let message):
            return "Configuração inválida do leitor: \(message)"
        }
    }

    /// Erro que o operador pode resolver sozinho no campo.
    var isRecoverable: Bool {
        switch self {
        case .sdkUnavailable:
            return false
        case .readerNotAvailable, .notConnected, .connectionFailed, .operationFailed,
             .radioError, .invalidConfiguration:
            return true
        }
    }
}

// MARK: - Protocol

/// Contrato de qualquer implementação de leitor RFID (hardware real ou mock).
///
/// Todos os publishers emitem na main queue. As implementações precisam
/// garantir que as transições de estado sejam serializadas e consistentes.
protocol RFIDReaderProtocol: AnyObject {

    // MARK: State

    var connectionState: RFIDConnectionState { get }
    var connectionStatePublisher: AnyPublisher<RFIDConnectionState, Never> { get }

    var discoveredReaders: [RFIDReaderInfo] { get }
    var discoveredReadersPublisher: AnyPublisher<[RFIDReaderInfo], Never> { get }

    /// Leituras únicas da sessão atual, **na ordem de leitura**.
    ///
    /// Ordem importa: a tela de vincular tag usa a última lida como "a tag que
    /// acabou de passar no leitor". O legado publicava a lista ordenada
    /// alfabeticamente e `.last` apontava para outra tag qualquer.
    var tagReads: [RFIDTagRead] { get }
    var tagReadsPublisher: AnyPublisher<[RFIDTagRead], Never> { get }

    var isScanning: Bool { get }
    var isScanningPublisher: AnyPublisher<Bool, Never> { get }

    /// Bateria do leitor conectado, 0 a 100.
    var batteryLevel: Int? { get }
    var batteryLevelPublisher: AnyPublisher<Int?, Never> { get }

    /// Último erro observado. `nil` depois de `clearError()` ou de uma operação
    /// bem-sucedida que o substitua.
    var lastError: RFIDReaderError? { get }
    var lastErrorPublisher: AnyPublisher<RFIDReaderError?, Never> { get }

    // MARK: Actions

    /// Começa a procurar leitores disponíveis (MFi/Bluetooth).
    func discoverReaders()

    /// Conecta a um leitor. O estado passa por `.connecting` e chega em
    /// `.connected`, ou volta para `.disconnected` com `lastError` preenchido.
    func connect(to reader: RFIDReaderInfo)

    /// Encerra a sessão e volta para `.disconnected`.
    func disconnect()

    /// Inicia inventário (rapid read). As tags aparecem em `tagReads`.
    func startInventory()

    /// Para o inventário em andamento.
    func stopInventory()

    /// Zera a lista de tags sem parar o inventário.
    func clearTags()

    /// Ajusta a potência da antena, em décimos de dBm (270 = 27,0 dBm).
    ///
    /// Sem controle de potência, o RFD40 no máximo lê o galpão inteiro e a
    /// conferência por proximidade não funciona: tudo vira "extra".
    func setAntennaPower(deciDbm: Int)

    /// Pede uma atualização de bateria ao leitor.
    func refreshBattery()

    /// Limpa `lastError`.
    func clearError()
}

// MARK: - Derived views

extension RFIDReaderProtocol {

    /// Só os EPCs normalizados, na ordem de leitura.
    var scannedTags: [String] {
        tagReads.map(\.tag)
    }

    /// A tag lida mais recentemente (por ordem de chegada, não alfabética).
    var lastReadTag: String? {
        tagReads.last?.tag
    }

    /// Mapa tag -> RSSI de pico, pronto para `rssi_por_tag` do payload de scan.
    var rssiByTag: [String: Int] {
        var out: [String: Int] = [:]
        for read in tagReads {
            if let rssi = read.rssi {
                out[read.tag] = rssi
            }
        }
        return out
    }
}
