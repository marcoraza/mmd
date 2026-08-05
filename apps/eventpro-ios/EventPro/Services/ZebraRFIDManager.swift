import Foundation
import Combine

/// Prova de build: `true` só quando o `ZebraRfidSdkFramework` entrou no target e
/// todo o `ZebraRFIDManager` abaixo foi compilado de verdade.
///
/// Existe para o CI conseguir afirmar isso num teste, em vez de confiar num
/// comentário. Enquanto o xcframework tiver slice de simulador — e a versão
/// 1.1.72 vendorizada tem —, o build de simulador do CI compila o código real
/// do SDK, não o fallback mock.
enum ZebraSDKAvailability {
    #if canImport(ZebraRfidSdkFramework)
    static let isCompiledIn = true
    #else
    static let isCompiledIn = false
    #endif
}

#if canImport(ZebraRfidSdkFramework)
import ZebraRfidSdkFramework

/// Implementação real de `RFIDReaderProtocol` sobre o Zebra RFID iOS SDK
/// (`ZebraRfidSdkFramework`, versão 1.1.72, vendorizado em
/// `apps/ios/Vendor/ZebraRfidSdkFramework`).
///
/// Escrita do zero contra as assinaturas reais dos headers públicos do
/// xcframework — `RfidSdkApi.h`, `RfidSdkApiDelegate.h`, `RfidSdkDefs.h`,
/// `RfidSdkFactory.h`. O manager do MMD legado usava constantes `CYCLOPSEVENT_*`
/// que não existem no SDK, ficava sob um `canImport` que nunca era verdadeiro, e
/// não tinha potência de antena, RSSI, bateria nem `deinit`.
///
/// Garantias desta implementação:
/// - **Serialização.** Todo acesso a estado mutável acontece em `queue`, uma
///   fila serial própria. Os callbacks do SDK chegam em thread do SDK e são
///   reenfileirados antes de tocar qualquer coisa.
/// - **Lifecycle.** `deinit` desinscreve eventos, solta o delegate e encerra a
///   sessão. O legado não tinha `deinit` e vazava o delegate.
/// - **Potência.** `setAntennaPower(deciDbm:)` grava na configuração de antena
///   e é respeitado pelo `srfidAccessConfig` de cada inventário, limitado pela
///   faixa real que o leitor reporta em `srfidGetReaderCapabilitiesInfo`.
/// - **RSSI e bateria.** RSSI de pico por tag vem de `srfidTagData.getPeakRSSI`;
///   bateria de `srfidEventBatteryNotity` e de `srfidRequestBatteryStatus`.
/// - **Erros tipados.** `RFIDReaderError`, separado de `connectionState`.
final class ZebraRFIDManager: NSObject, RFIDReaderProtocol {

    // MARK: - Combine Subjects

    private let connectionStateSubject = CurrentValueSubject<RFIDConnectionState, Never>(.disconnected)
    private let discoveredReadersSubject = CurrentValueSubject<[RFIDReaderInfo], Never>([])
    private let tagReadsSubject = CurrentValueSubject<[RFIDTagRead], Never>([])
    private let isScanningSubject = CurrentValueSubject<Bool, Never>(false)
    private let batteryLevelSubject = CurrentValueSubject<Int?, Never>(nil)
    private let lastErrorSubject = CurrentValueSubject<RFIDReaderError?, Never>(nil)

    // MARK: - RFIDReaderProtocol (estado)

    var connectionState: RFIDConnectionState { connectionStateSubject.value }
    var connectionStatePublisher: AnyPublisher<RFIDConnectionState, Never> {
        connectionStateSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    var discoveredReaders: [RFIDReaderInfo] { discoveredReadersSubject.value }
    var discoveredReadersPublisher: AnyPublisher<[RFIDReaderInfo], Never> {
        discoveredReadersSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    var tagReads: [RFIDTagRead] { tagReadsSubject.value }
    var tagReadsPublisher: AnyPublisher<[RFIDTagRead], Never> {
        tagReadsSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    var isScanning: Bool { isScanningSubject.value }
    var isScanningPublisher: AnyPublisher<Bool, Never> {
        isScanningSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    var batteryLevel: Int? { batteryLevelSubject.value }
    var batteryLevelPublisher: AnyPublisher<Int?, Never> {
        batteryLevelSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    var lastError: RFIDReaderError? { lastErrorSubject.value }
    var lastErrorPublisher: AnyPublisher<RFIDReaderError?, Never> {
        lastErrorSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    // MARK: - SDK

    private let api: srfidISdkApi

    /// Fila serial dona de todo o estado mutável abaixo.
    private let queue = DispatchQueue(label: "com.emdash.eventpro.rfid.zebra", qos: .userInitiated)

    // MARK: - Estado protegido por `queue`

    /// Leitores conhecidos, por id do SDK.
    private var knownReaders: [Int32: srfidReaderInfo] = [:]

    /// Sessão ativa. `nil` quando desconectado.
    private var activeReaderID: Int32?

    /// Tags já vistas nesta sessão, para deduplicar sem perder a ordem.
    private var seenTags: [String: Int] = [:]

    /// Potência desejada em décimos de dBm, antes do clamp por capacidade.
    private var desiredPowerDeciDbm = AppConfig.defaultAntennaPowerDeciDbm

    /// Faixa real reportada pelo leitor conectado.
    private var powerRange: (min: Int, max: Int, step: Int)?

    // MARK: - Máscara de eventos

    /// Só o que o EventPro consome. Proximidade multi-tag, wifi e temperatura
    /// ficam de fora de propósito: evento que ninguém lê é ruído no canal BT.
    private static let eventMask: Int32 =
        SRFID_EVENT_READER_APPEARANCE
        | SRFID_EVENT_READER_DISAPPEARANCE
        | SRFID_EVENT_SESSION_ESTABLISHMENT
        | SRFID_EVENT_SESSION_TERMINATION
        | SRFID_EVENT_MASK_READ
        | SRFID_EVENT_MASK_STATUS
        | SRFID_EVENT_MASK_TRIGGER
        | SRFID_EVENT_MASK_BATTERY
        | SRFID_EVENT_MASK_STATUS_OPERENDSUMMARY
        | SRFID_EVENT_MASK_RADIOERROR

    // MARK: - Init / deinit

    override init() {
        self.api = srfidSdkFactory.createRfidSdkApiInstance()
        super.init()

        api.srfidSetDelegate(self)
        // MFi cobre o RFD40 por cabo/Bluetooth clássico; BTLE cobre o pareamento
        // por Bluetooth Low Energy. ALL deixa o SDK escolher.
        _ = api.srfidSetOperationalMode(SRFID_OPMODE_ALL)
        _ = api.srfidSubsribeForEvents(Self.eventMask)
        _ = api.srfidEnableAvailableReadersDetection(true)
        _ = api.srfidEnableAutomaticSessionReestablishment(true)
    }

    deinit {
        // Sem `queue` aqui: em `deinit` não existe mais ninguém segurando o
        // objeto, então não há concorrência a serializar, e um hop assíncrono
        // capturaria `self` que está morrendo. Chamadas diretas e síncronas.
        if let readerID = activeReaderID {
            var statusMessage: NSString?
            _ = api.srfidStopRapidRead(readerID, aStatusMessage: &statusMessage)
            _ = api.srfidTerminateCommunicationSession(readerID)
        }
        _ = api.srfidEnableAvailableReadersDetection(false)
        _ = api.srfidUnsubsribeForEvents(Self.eventMask)
        api.srfidSetDelegate(nil)
    }

    // MARK: - RFIDReaderProtocol (ações)

    func discoverReaders() {
        queue.async { [self] in
            lastErrorSubject.send(nil)
            connectionStateSubject.send(.discovering)
            _ = api.srfidEnableAvailableReadersDetection(true)
            reloadReaderLists()
        }
    }

    func connect(to reader: RFIDReaderInfo) {
        queue.async { [self] in
            guard let readerID = Int32(reader.id) else {
                lastErrorSubject.send(.invalidConfiguration("Id de leitor inválido: \(reader.id)"))
                return
            }

            lastErrorSubject.send(nil)
            connectionStateSubject.send(.connecting)

            let result = api.srfidEstablishCommunicationSession(readerID)
            guard Self.succeeded(result) else {
                lastErrorSubject.send(
                    .connectionFailed(sdkCode: Self.resultName(result), message: nil)
                )
                connectionStateSubject.send(.disconnected)
                return
            }
            // O sucesso real chega em srfidEventCommunicationSessionEstablished.
        }
    }

    func disconnect() {
        queue.async { [self] in
            guard let readerID = activeReaderID else {
                connectionStateSubject.send(.disconnected)
                return
            }

            var statusMessage: NSString?
            _ = api.srfidStopRapidRead(readerID, aStatusMessage: &statusMessage)
            _ = api.srfidTerminateCommunicationSession(readerID)

            activeReaderID = nil
            powerRange = nil
            isScanningSubject.send(false)
            batteryLevelSubject.send(nil)
            connectionStateSubject.send(.disconnected)
        }
    }

    func startInventory() {
        queue.async { [self] in
            guard let readerID = activeReaderID else {
                lastErrorSubject.send(.notConnected)
                return
            }
            guard !isScanningSubject.value else { return }

            lastErrorSubject.send(nil)

            var statusMessage: NSString?
            let result = api.srfidStartRapidRead(
                readerID,
                aReportConfig: makeReportConfig(),
                aAccessConfig: makeAccessConfig(),
                aStatusMessage: &statusMessage
            )

            guard Self.succeeded(result) else {
                lastErrorSubject.send(
                    .operationFailed(
                        operation: "iniciar leitura",
                        sdkCode: Self.resultName(result),
                        message: statusMessage as String?
                    )
                )
                return
            }

            // Otimista: o SDK confirma em srfidEventStatusNotify com
            // SRFID_EVENT_STATUS_OPERATION_START, mas a UI não deve esperar o
            // round-trip Bluetooth para mostrar que o gatilho pegou.
            isScanningSubject.send(true)
        }
    }

    func stopInventory() {
        queue.async { [self] in
            guard let readerID = activeReaderID else {
                isScanningSubject.send(false)
                return
            }

            var statusMessage: NSString?
            let result = api.srfidStopRapidRead(readerID, aStatusMessage: &statusMessage)

            if !Self.succeeded(result) {
                lastErrorSubject.send(
                    .operationFailed(
                        operation: "parar leitura",
                        sdkCode: Self.resultName(result),
                        message: statusMessage as String?
                    )
                )
            }

            isScanningSubject.send(false)
        }
    }

    func clearTags() {
        queue.async { [self] in
            seenTags.removeAll()
            tagReadsSubject.send([])
        }
    }

    func setAntennaPower(deciDbm: Int) {
        queue.async { [self] in
            desiredPowerDeciDbm = deciDbm
            guard activeReaderID != nil else { return }
            applyAntennaPower()
        }
    }

    func refreshBattery() {
        queue.async { [self] in
            guard let readerID = activeReaderID else {
                lastErrorSubject.send(.notConnected)
                return
            }
            // Assíncrono: a resposta chega em srfidEventBatteryNotity.
            _ = api.srfidRequestBatteryStatus(readerID)
        }
    }

    func clearError() {
        queue.async { [self] in
            lastErrorSubject.send(nil)
        }
    }

    // MARK: - Configuração do leitor (sempre em `queue`)

    /// Roda uma vez por sessão estabelecida.
    private func configureConnectedReader(_ readerID: Int32) {
        readCapabilities(readerID)
        applyAntennaPower()
        configureTriggers(readerID)
        configureTagReport(readerID)
        _ = api.srfidRequestBatteryStatus(readerID)
    }

    private func readCapabilities(_ readerID: Int32) {
        var capabilities: srfidReaderCapabilitiesInfo?
        var statusMessage: NSString?
        let result = api.srfidGetReaderCapabilitiesInfo(
            readerID,
            aReaderCapabilitiesInfo: &capabilities,
            aStatusMessage: &statusMessage
        )

        guard Self.succeeded(result), let capabilities else {
            powerRange = nil
            return
        }

        let minPower = Int(capabilities.getMinPower())
        let maxPower = Int(capabilities.getMaxPower())
        let step = max(1, Int(capabilities.getPowerStep()))
        guard maxPower > minPower else {
            powerRange = nil
            return
        }
        powerRange = (min: minPower, max: maxPower, step: step)
    }

    /// Potência efetiva: o desejado, limitado pela faixa real e alinhado ao
    /// passo que o leitor aceita.
    private func effectivePowerDeciDbm() -> Int {
        guard let range = powerRange else {
            return min(AppConfig.maxAntennaPowerDeciDbm,
                       max(AppConfig.minAntennaPowerDeciDbm, desiredPowerDeciDbm))
        }
        let clamped = min(range.max, max(range.min, desiredPowerDeciDbm))
        let steps = (clamped - range.min) / range.step
        return min(range.max, range.min + steps * range.step)
    }

    private func applyAntennaPower() {
        guard let readerID = activeReaderID else { return }

        var configuration: srfidAntennaConfiguration?
        var statusMessage: NSString?
        let getResult = api.srfidGetAntennaConfiguration(
            readerID,
            aAntennaConfiguration: &configuration,
            aStatusMessage: &statusMessage
        )

        guard Self.succeeded(getResult), let configuration else {
            lastErrorSubject.send(
                .operationFailed(
                    operation: "ler configuração de antena",
                    sdkCode: Self.resultName(getResult),
                    message: statusMessage as String?
                )
            )
            return
        }

        configuration.setPower(Int16(clamping: effectivePowerDeciDbm()))
        // Sem pré-filtro de seleção: a filtragem do EventPro é por packing no
        // servidor, não por máscara de EPC no leitor.
        configuration.setDoSelect(false)

        var setStatusMessage: NSString?
        let setResult = api.srfidSetAntennaConfiguration(
            readerID,
            aAntennaConfiguration: configuration,
            aStatusMessage: &setStatusMessage
        )

        if !Self.succeeded(setResult) {
            lastErrorSubject.send(
                .operationFailed(
                    operation: "ajustar potência da antena",
                    sdkCode: Self.resultName(setResult),
                    message: setStatusMessage as String?
                )
            )
        }
    }

    /// Gatilhos imediatos: o app inicia e para a leitura. O gatilho físico do
    /// RFD40 continua chegando por `srfidEventTriggerNotify` e é tratado lá.
    private func configureTriggers(_ readerID: Int32) {
        let start = srfidStartTriggerConfig()
        start.setStartOnHandheldTrigger(false)
        start.setTriggerType(SRFID_TRIGGERTYPE_PRESS)
        start.setStartDelay(0)
        start.setRepeatMonitoring(false)

        var startStatus: NSString?
        _ = api.srfidSetStartTriggerConfiguration(
            readerID,
            aStartTriggeConfig: start,
            aStatusMessage: &startStatus
        )

        let stop = srfidStopTriggerConfig()
        stop.setStopOnHandheldTrigger(false)
        stop.setTriggerType(SRFID_TRIGGERTYPE_RELEASE)
        stop.setStopOnTimeout(false)
        // Grafia do SDK: o setter é mesmo `setStopTimout`, sem o segundo "e".
        stop.setStopTimout(0)
        stop.setStopOnTagCount(false)
        stop.setStopTagCount(0)
        stop.setStopOnInventoryCount(false)
        stop.setStopInventoryCount(0)
        stop.setStopOnAccessCount(false)
        stop.setStopAccessCount(0)

        var stopStatus: NSString?
        _ = api.srfidSetStopTriggerConfiguration(
            readerID,
            aStopTriggeConfig: stop,
            aStatusMessage: &stopStatus
        )
    }

    /// Pede RSSI no relatório do leitor. Sem isso `getPeakRSSI` vem zerado e não
    /// existe base para proximidade nem para "achar item".
    private func configureTagReport(_ readerID: Int32) {
        let report = srfidTagReportConfig()
        report.setIncRSSI(true)
        report.setIncFirstSeenTime(true)
        report.setIncLastSeenTime(true)
        report.setIncTagSeenCount(true)
        report.setIncPC(false)
        report.setIncPhase(false)
        // Nome curto de propósito: neste tipo o setter é `setIncChannelIdx`,
        // enquanto em `srfidReportConfig` é `setIncChannelIndex`.
        report.setIncChannelIdx(false)

        var statusMessage: NSString?
        _ = api.srfidSetTagReportConfiguration(
            readerID,
            aTagReportConfig: report,
            aStatusMessage: &statusMessage
        )
    }

    private func makeReportConfig() -> srfidReportConfig {
        let config = srfidReportConfig()
        config.setIncRSSI(true)
        config.setIncFirstSeenTime(true)
        config.setIncLastSeenTime(true)
        config.setIncTagSeenCount(true)
        config.setIncPC(false)
        config.setIncPhase(false)
        config.setIncChannelIndex(false)
        return config
    }

    private func makeAccessConfig() -> srfidAccessConfig {
        let config = srfidAccessConfig()
        config.setPower(Int16(clamping: effectivePowerDeciDbm()))
        config.setDoSelect(false)
        return config
    }

    // MARK: - Listas de leitores (sempre em `queue`)

    private func reloadReaderLists() {
        var available: NSMutableArray?
        var active: NSMutableArray?
        _ = api.srfidGetAvailableReadersList(&available)
        _ = api.srfidGetActiveReadersList(&active)

        var merged: [Int32: srfidReaderInfo] = [:]
        for list in [available, active] {
            guard let list else { continue }
            for element in list {
                guard let reader = element as? srfidReaderInfo else { continue }
                merged[reader.getReaderID()] = reader
            }
        }

        knownReaders = merged
        publishDiscoveredReaders()
    }

    private func publishDiscoveredReaders() {
        let readers = knownReaders
            .values
            .map(Self.readerInfo(from:))
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        discoveredReadersSubject.send(readers)
    }

    private static func readerInfo(from reader: srfidReaderInfo) -> RFIDReaderInfo {
        let readerID = reader.getReaderID()
        let name = reader.getReaderName() ?? "Leitor \(readerID)"
        return RFIDReaderInfo(
            id: String(readerID),
            name: name,
            // O SDK não expõe o serial de fábrica no `srfidReaderInfo`: ele vem
            // de `srfidGetReaderCapabilitiesInfo` depois da sessão. Aqui fica
            // nil e é preenchido no evento de sessão estabelecida.
            serialNumber: nil,
            batteryLevel: nil
        )
    }

    /// Nome do leitor mais serial de fábrica, disponível só com sessão ativa.
    private func connectedReaderInfo(_ readerID: Int32) -> RFIDReaderInfo {
        let base = knownReaders[readerID].map(Self.readerInfo(from:))
            ?? RFIDReaderInfo(id: String(readerID), name: "Leitor \(readerID)")

        var capabilities: srfidReaderCapabilitiesInfo?
        var statusMessage: NSString?
        let result = api.srfidGetReaderCapabilitiesInfo(
            readerID,
            aReaderCapabilitiesInfo: &capabilities,
            aStatusMessage: &statusMessage
        )

        let serial: String? = {
            guard Self.succeeded(result), let capabilities else { return nil }
            let value = capabilities.getSerialNumber()?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (value?.isEmpty ?? true) ? nil : value
        }()

        return RFIDReaderInfo(
            id: base.id,
            name: base.name,
            serialNumber: serial,
            batteryLevel: batteryLevelSubject.value
        )
    }

    // MARK: - Registro de tag (sempre em `queue`)

    private func record(rawTag: String, rssi: Int?) {
        // Normaliza no cliente com a mesma regra do servidor (divergência D2):
        // o SDK pode entregar o EPC com separador e o casamento contra a
        // resposta da API quebraria em silêncio.
        guard let tag = RfidTagNormalizer.normalizeIfValid(rawTag) else { return }

        var reads = tagReadsSubject.value

        if let index = seenTags[tag] {
            let merged = reads[index].mergingPeak(rssi: rssi)
            guard merged != reads[index] else { return }
            reads[index] = merged
        } else {
            seenTags[tag] = reads.count
            reads.append(RFIDTagRead(tag: tag, rssi: rssi))
        }

        tagReadsSubject.send(reads)
    }

    // MARK: - Helpers de SRFID_RESULT

    /// Comparação por `rawValue`: o enum C do SDK não é `NS_ENUM`, então o
    /// Swift importa como struct `RawRepresentable`; comparar o cru vale nas
    /// duas formas de importação e não depende de conformidade sintetizada.
    private static func succeeded(_ result: SRFID_RESULT) -> Bool {
        result.rawValue == SRFID_RESULT_SUCCESS.rawValue
    }

    /// Nome da constante, para log e para a mensagem de erro do operador.
    private static func resultName(_ result: SRFID_RESULT) -> String {
        switch result.rawValue {
        case SRFID_RESULT_SUCCESS.rawValue: return "SRFID_RESULT_SUCCESS"
        case SRFID_RESULT_FAILURE.rawValue: return "SRFID_RESULT_FAILURE"
        case SRFID_RESULT_READER_NOT_AVAILABLE.rawValue: return "SRFID_RESULT_READER_NOT_AVAILABLE"
        case SRFID_RESULT_INVALID_PARAMS.rawValue: return "SRFID_RESULT_INVALID_PARAMS"
        case SRFID_RESULT_RESPONSE_TIMEOUT.rawValue: return "SRFID_RESULT_RESPONSE_TIMEOUT"
        case SRFID_RESULT_NOT_SUPPORTED.rawValue: return "SRFID_RESULT_NOT_SUPPORTED"
        case SRFID_RESULT_RESPONSE_ERROR.rawValue: return "SRFID_RESULT_RESPONSE_ERROR"
        case SRFID_RESULT_WRONG_ASCII_PASSWORD.rawValue: return "SRFID_RESULT_WRONG_ASCII_PASSWORD"
        case SRFID_RESULT_ASCII_CONNECTION_REQUIRED.rawValue: return "SRFID_RESULT_ASCII_CONNECTION_REQUIRED"
        default: return "SRFID_RESULT_\(result.rawValue)"
        }
    }
}

// MARK: - srfidISdkApiDelegate

/// O protocolo do SDK não tem `@optional`: todos os métodos são obrigatórios.
/// Os callbacks chegam em thread do SDK, então **todo** corpo aqui só faz um
/// `queue.async` e nada mais.
extension ZebraRFIDManager: srfidISdkApiDelegate {

    func srfidEventReaderAppeared(_ availableReader: srfidReaderInfo!) {
        guard let availableReader else { return }
        queue.async { [self] in
            knownReaders[availableReader.getReaderID()] = availableReader
            publishDiscoveredReaders()
        }
    }

    func srfidEventReaderDisappeared(_ readerID: Int32) {
        queue.async { [self] in
            knownReaders.removeValue(forKey: readerID)
            publishDiscoveredReaders()

            if activeReaderID == readerID {
                activeReaderID = nil
                powerRange = nil
                isScanningSubject.send(false)
                batteryLevelSubject.send(nil)
                connectionStateSubject.send(.disconnected)
                lastErrorSubject.send(.readerNotAvailable)
            }
        }
    }

    func srfidEventCommunicationSessionEstablished(_ activeReader: srfidReaderInfo!) {
        guard let activeReader else { return }
        queue.async { [self] in
            let readerID = activeReader.getReaderID()
            knownReaders[readerID] = activeReader
            activeReaderID = readerID

            configureConnectedReader(readerID)

            publishDiscoveredReaders()
            lastErrorSubject.send(nil)
            connectionStateSubject.send(.connected(connectedReaderInfo(readerID)))
        }
    }

    func srfidEventCommunicationSessionTerminated(_ readerID: Int32) {
        queue.async { [self] in
            guard activeReaderID == readerID else { return }
            activeReaderID = nil
            powerRange = nil
            isScanningSubject.send(false)
            batteryLevelSubject.send(nil)
            connectionStateSubject.send(.disconnected)
        }
    }

    func srfidEventReadNotify(_ readerID: Int32, aTagData tagData: srfidTagData!) {
        guard let tagData, let rawTag = tagData.getTagId() else { return }
        let peak = Int(tagData.getPeakRSSI())
        queue.async { [self] in
            guard activeReaderID == readerID else { return }
            // RSSI zerado significa "não reportado" (o leitor devolve valores
            // negativos em dBm), não "sinal perfeito".
            record(rawTag: rawTag, rssi: peak == 0 ? nil : peak)
        }
    }

    func srfidEventStatusNotify(_ readerID: Int32, aEvent event: SRFID_EVENT_STATUS, aNotification notificationData: Any!) {
        let radioCause = (notificationData as? srfidRadioErrorEvent).map { errorEvent -> String in
            let cause = errorEvent.getCause() ?? "desconhecida"
            return "\(cause) (código \(errorEvent.getErrorNumber()))"
        }

        queue.async { [self] in
            guard activeReaderID == readerID else { return }

            switch event.rawValue {
            case SRFID_EVENT_STATUS_OPERATION_START.rawValue:
                isScanningSubject.send(true)

            case SRFID_EVENT_STATUS_OPERATION_STOP.rawValue,
                 SRFID_EVENT_STATUS_OPERATION_END_SUMMARY.rawValue:
                isScanningSubject.send(false)

            case SRFID_EVENT_STATUS_OPERATION_FAILED.rawValue:
                isScanningSubject.send(false)
                lastErrorSubject.send(
                    .operationFailed(
                        operation: "leitura",
                        sdkCode: "SRFID_EVENT_STATUS_OPERATION_FAILED",
                        message: nil
                    )
                )

            case SRFID_EVENT_STATUS_RADIOERROR.rawValue:
                isScanningSubject.send(false)
                lastErrorSubject.send(.radioError(message: radioCause ?? "causa desconhecida"))

            default:
                break
            }
        }
    }

    func srfidEventProximityNotify(_ readerID: Int32, aProximityPercent proximityPercent: Int32) {
        // "Achar item" por proximidade é feature da fase 7. O evento fica
        // assinado fora da máscara, então este callback não deve chegar.
    }

    func srfidEventMultiProximityNotify(_ readerID: Int32, aTagData tagData: srfidTagData!) {
        // Idem: localização multi-tag não está na máscara de eventos.
    }

    func srfidEventTriggerNotify(_ readerID: Int32, aTriggerEvent triggerEvent: SRFID_TRIGGEREVENT) {
        // O gatilho físico do RFD40 é o jeito natural de operar no galpão: o
        // operador não vai tocar na tela com o leitor na mão.
        switch triggerEvent.rawValue {
        case SRFID_TRIGGEREVENT_PRESSED.rawValue:
            startInventory()
        case SRFID_TRIGGEREVENT_RELEASED.rawValue:
            stopInventory()
        default:
            break
        }
    }

    func srfidEventBatteryNotity(_ readerID: Int32, aBatteryEvent batteryEvent: srfidBatteryEvent!) {
        guard let batteryEvent else { return }
        let level = Int(batteryEvent.getPowerLevel())
        queue.async { [self] in
            guard activeReaderID == readerID else { return }
            batteryLevelSubject.send(max(0, min(100, level)))
            if case .connected = connectionStateSubject.value {
                connectionStateSubject.send(.connected(connectedReaderInfo(readerID)))
            }
        }
    }

    func srfidEventWifiScan(_ readerID: Int32, wlanSCanObject wlanScanObject: srfidWlanScanList!) {
        // O EventPro não usa o rádio Wi-Fi do leitor.
    }
}

#endif
