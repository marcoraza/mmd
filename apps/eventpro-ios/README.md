# EventPro iOS

App de campo do EventPro: check-out, retorno, conferência RFID e vínculo de tag,
com leitor Zebra RFD40 por Bluetooth/MFi e QR por câmera.

Sucessor de `apps/ios/MMDEstoque` do repo `marcoraza/mmd`. Mesma operação,
produto renomeado, SDK Zebra real no build, auth de verdade e as divergências
D1–D11 de `docs/contratos-api.md` corrigidas do lado do cliente.

---

## Estrutura

```
apps/ios/
├── project.yml                     # Spec do XcodeGen (o .xcodeproj nao e versionado)
├── Config/
│   ├── Base.xcconfig               # Settings comuns; inclui Signing.xcconfig se existir
│   └── Signing.xcconfig.example    # Modelo do DEVELOPMENT_TEAM (copie e preencha)
├── Vendor/
│   └── ZebraRfidSdkFramework/      # SDK Zebra vendorizado + PROVENANCE.md
├── EventPro/
│   ├── App/                        # Ponto de entrada SwiftUI
│   ├── Config/AppConfig.swift      # Endpoints e preferencias locais
│   ├── Models/                     # Schema Supabase + contratos de API (sem SwiftUI)
│   ├── Services/                   # RFID, HTTP, auth, Keychain, normalizacao de tag
│   ├── ViewModels/                 # Regras de fluxo
│   ├── Views/                      # UI minima SwiftUI (substituida na fase 7)
│   └── Resources/Info.plist
└── EventProTests/
```

## Como rodar

```sh
brew install xcodegen
cd apps/ios
xcodegen generate
open EventPro.xcodeproj
```

O `.xcodeproj` **não é versionado**: é sempre gerado do `project.yml`. Depois de
mexer em arquivos, rode `xcodegen generate` de novo.

### Assinatura (DEVELOPMENT_TEAM)

O Team ID não entra no repo. `Config/Base.xcconfig` faz um `#include?` opcional
de `Config/Signing.xcconfig`, que está no `.gitignore`:

```sh
cp Config/Signing.xcconfig.example Config/Signing.xcconfig
# edite e troque ABCDE12345 pelo Team ID de 10 caracteres da conta Apple da MMD
xcodegen generate
```

Sem esse arquivo o projeto continua gerando e compilando — é assim que o CI roda,
com `CODE_SIGNING_ALLOWED=NO`. Só a instalação em device precisa do time.

Em script, dá para passar direto (setting de linha de comando ganha do xcconfig):

```sh
xcodebuild -project EventPro.xcodeproj -scheme EventPro DEVELOPMENT_TEAM=ABCDE12345 ...
```

### Configuração de servidor

Não há credencial embutida (o repo é público). Na primeira execução, tela de
login → **Configuração de servidor**:

| Campo | Valor |
|---|---|
| Supabase URL | `https://bphmxticdyuctovfumcj.supabase.co` |
| Supabase anon key | chave anônima do projeto |
| Web API URL | base do BFF, ex.: `https://eventpro-staging.vercel.app` |

Depois é login por e-mail e senha (Supabase Auth). O token vai para o Keychain e
é renovado sozinho.

> **Atenção de staging:** `MMD_READONLY` precisa estar explicitamente desligada
> no ambiente do BFF. O default é `true`, e com ela ligada toda escrita responde
> 400 `"Modo somente leitura: alterações não são salvas."` — o app mostra só o
> erro HTTP e o smoke test parece quebrado sem motivo (divergência D10).

---

## SDK Zebra

O `ZebraRfidSdkFramework.xcframework` (versão **1.1.72**, pod `ZebraRfidiOSSdk`,
repo `ZebraDevs/alt-rfid-ios-sdk`) está **vendorizado** em
`Vendor/ZebraRfidSdkFramework/`. Origem, commit, hashes e passo de atualização
estão em `Vendor/ZebraRfidSdkFramework/PROVENANCE.md`.

O xcframework tem slice `ios-arm64_x86_64-simulator`, então o build de simulador
compila `Services/ZebraRFIDManager.swift` de verdade. O `#if
canImport(ZebraRfidSdkFramework)` continua no arquivo, mas agora é **transitório
e provado**: o teste `ZebraSDKBuildTests` falha se o framework sair do build, e o
CI confere a existência da slice de simulador antes de compilar.

No app legado esse mesmo `canImport` **nunca** era verdadeiro — o SDK não estava
no projeto, o código usava constantes `CYCLOPSEVENT_*` que não existem, e em
runtime o app sempre caía no mock em silêncio.

### API real usada (fonte: headers do xcframework)

Tudo abaixo saiu de
`Vendor/ZebraRfidSdkFramework/ZebraRfidSdkFramework.xcframework/ios-arm64/ZebraRfidSdkFramework.framework/Headers/`.

| Header | O que o EventPro usa |
|---|---|
| `RfidSdkFactory.h` | `srfidSdkFactory.createRfidSdkApiInstance()` |
| `RfidSdkApi.h` | `srfidISdkApi`: `srfidSetDelegate:`, `srfidSetOperationalMode:`, `srfidSubsribeForEvents:` / `srfidUnsubsribeForEvents:`, `srfidEnableAvailableReadersDetection:`, `srfidEnableAutomaticSessionReestablishment:`, `srfidGetAvailableReadersList:`, `srfidGetActiveReadersList:`, `srfidEstablishCommunicationSession:`, `srfidTerminateCommunicationSession:`, `srfidStartRapidRead:aReportConfig:aAccessConfig:aStatusMessage:`, `srfidStopRapidRead:aStatusMessage:`, `srfidGetAntennaConfiguration:...` / `srfidSetAntennaConfiguration:...`, `srfidGetReaderCapabilitiesInfo:...`, `srfidSetStartTriggerConfiguration:...`, `srfidSetStopTriggerConfiguration:...`, `srfidSetTagReportConfiguration:...`, `srfidRequestBatteryStatus:` |
| `RfidSdkApiDelegate.h` | `srfidISdkApiDelegate` (10 métodos, **nenhum opcional**): `srfidEventReaderAppeared:`, `srfidEventReaderDisappeared:`, `srfidEventCommunicationSessionEstablished:`, `srfidEventCommunicationSessionTerminated:`, `srfidEventReadNotify:aTagData:`, `srfidEventStatusNotify:aEvent:aNotification:`, `srfidEventProximityNotify:aProximityPercent:`, `srfidEventMultiProximityNotify:aTagData:`, `srfidEventTriggerNotify:aTriggerEvent:`, `srfidEventBatteryNotity:aBatteryEvent:` (o typo "Notity" é do SDK), `srfidEventWifiScan:wlanSCanObject:` |
| `RfidSdkDefs.h` | `SRFID_RESULT_*`, `SRFID_OPMODE_ALL`, `SRFID_EVENT_*` (máscara de bits), `SRFID_EVENT_STATUS_*`, `SRFID_TRIGGEREVENT_*`, `SRFID_TRIGGERTYPE_*` |
| `RfidTagData.h` | `getTagId()`, `getPeakRSSI()` |
| `RfidBatteryEvent.h` | `getPowerLevel()`, `getIsCharging()` |
| `RfidAntennaConfiguration.h` | `getPower()` / `setPower(short)` — potência em **décimos de dBm** |
| `RfidReaderCapabilitiesInfo.h` | `getMinPower()`, `getMaxPower()`, `getPowerStep()`, `getSerialNumber()` |
| `RfidReportConfig.h` | `setIncRSSI:` (sem isso o RSSI vem zerado) |
| `RfidTagReportConfig.h` | `setIncRSSI:`, `setIncChannelIdx:` (aqui é `Idx`; em `srfidReportConfig` é `ChannelIndex`) |
| `RfidStopTriggerConfig.h` | `setStopTimout:` — a grafia com typo é a do SDK |
| `RfidRadioErrorEvent.h` | `getCause()`, `getErrorNumber()` |

Detalhe de importação para Swift: os enums do SDK **não** usam `NS_ENUM`, então o
Clang importer os traz como `struct` `RawRepresentable`. As comparações no
`ZebraRFIDManager` são feitas por `.rawValue`, que vale nas duas formas possíveis
de importação.

### Info.plist e MFi

`UISupportedExternalAccessoryProtocols` declara:

- `com.zebra.rfd8X00_easytext` — protocolo dos leitores RFID Zebra, RFD40
  incluído. **X maiúsculo**: essa é a string que existe de fato no binário do SDK
  (`strings ZebraRfidSdkFramework | grep easytext`) e a que a documentação da
  Zebra manda declarar. O app legado tinha `rfd8x00` minúsculo.
- `com.symbol.rfd8X00_easytext` — necessário só para modelos RFD8500 antigos, e
  também presente no binário.

Outras correções do plist, todas apontadas na auditoria (seção 3.3):

| Antes (MMD) | Agora | Por quê |
|---|---|---|
| `UIRequiredDeviceCapabilities: armv7` | `arm64` | armv7 é 32 bits, morto desde o iPhone 5s |
| `NSBluetoothPeripheralUsageDescription` | removido | deprecado; `NSBluetoothAlwaysUsageDescription` cobre |
| `NSLocalNetworkUsageDescription` | removido | MFi não usa rede local; a chave só gera um prompt sem sentido |
| textos genéricos | pt-BR com a marca EventPro | é o que o operador lê no prompt |

Mantidos: `UIBackgroundModes: external-accessory` (a sessão com o RFD40 precisa
sobreviver ao app em background) e `NSCameraUsageDescription` (QR).

---

## Correções feitas na portagem

### D1 — retorno com `NAO_VOLTOU` (era bloqueante)

`ReturnViewModel.buildReturnProjectItems()` agora produz **uma entrada por
unidade em campo**, sempre. Item que o operador não conferiu vira `NAO_VOLTOU`
explícito, com confirmação na finalização (`requerConfirmacaoDePendentes`), e
nunca some do payload. É o que faz a chamada passar na cobertura total exigida
pela RPC `checkin_projeto` e o que torna `retorno_pendencias` alcançável pelo
mobile pela primeira vez.

### D2 — normalização de tag no cliente

`RfidTagNormalizer` espelha o `normalizeRfidTag` do servidor: `trim`,
`uppercase`, remoção de espaço/`:`/`-`, validação `[A-Z0-9]{8,96}` e dedupe
preservando a ordem de chegada. Aplicada na leitura (`ZebraRFIDManager.record`)
e de novo antes de enviar (`APIClient.recordRfidScans`), então o que o app casa
contra `resolved[].tag_rfid` é exatamente o que o servidor devolve.

### D3 — sem credencial, sem requisição

`APIClient.makeWebApiRequest` **recusa** a chamada quando não há token
(`APIError.naoAutenticado`), em vez de mandar sem `Authorization` e deixar o BFF
cair no caminho de cookie — que, com `MMD_REQUIRE_AUTH` desligada, executava
check-out real como admin anônimo.

### D7 — RSSI e localização

`RFIDTagRead` carrega `rssi` (dBm, pico), `srfidReportConfig`/`srfidTagReportConfig`
pedem RSSI ao leitor, e `RfidScanRequest` ganhou os campos **aditivos**
`rssi_por_tag` e `localizacao`. Quando não há RSSI, os campos são omitidos e o
corpo fica idêntico ao do contrato congelado.

### D9 — ids em minúsculas

`APIClient.pathId` converte `UUID.uuidString` para minúsculas em path e corpo.

### Ordenação de `scannedTags`

O legado publicava `Array(tagSet).sorted()`: a ordem alfabética apagava a ordem
de leitura, e a tela de vincular tag usava `.last` achando que pegava a etiqueta
que acabou de passar no leitor. Agora `tagReads` preserva a ordem de chegada e
existe `lastReadTag` explícito.

### `ZebraRFIDManager` novo

Escrito do zero contra as assinaturas reais: potência de antena limitada pela
faixa que o leitor reporta, bateria e RSSI expostos, `deinit` que desinscreve
eventos, solta o delegate e encerra a sessão, callbacks todos serializados numa
fila própria, e erros em `RFIDReaderError` — enum tipado, **separado** de
`RFIDConnectionState`, que não tem mais caso de erro.

### Auth real

`AuthService` faz login por senha no GoTrue (`POST /auth/v1/token?grant_type=password`),
guarda tokens no Keychain (`kSecAttrAccessibleAfterFirstUnlock`), renova sozinho
com margem de 60 s e serializa renovações concorrentes numa única `Task` (o
GoTrue rotaciona o refresh token a cada uso). O `APIClient` pede o token aqui;
não existe mais campo de "cole seu JWT" em Ajustes.

### Escrita direta no banco: removida

`registerCheckout`, `registerReturn`, `updateProjectStatus` e o `linkTag` por
PATCH no PostgREST saíram. O PostgREST continua sendo usado **só para leitura**.

---

## Gap conhecido: vínculo de tag

Não existe endpoint de vínculo de tag no contrato congelado (gap 4.2 da
auditoria), e o caminho legado (PATCH direto em `serial_numbers`) foi aposentado
de propósito. A tela **Etiquetar** funciona até a seleção do serial e a leitura
da etiqueta; a gravação falha com `APIError.endpointPendente`, dizendo o que
falta.

Para fechar: especificar `POST /api/seriais/{id}/tag` em `docs/contratos-api.md`
(versão nova do documento), implementar no BFF e trocar o corpo de
`APIClient.linkTag`. Reintroduzir o PATCH no app seria regressão de arquitetura.

---

## CI

`.github/workflows/ios.yml`, runner `macos-14`. O que ele prova:

1. O xcframework da Zebra existe e **tem slice de simulador** (falha explícita se
   perder — senão o CI voltaria a testar só o caminho mock).
2. `xcodegen generate` produz um projeto válido a partir do `project.yml`.
3. `xcodebuild build-for-testing` compila app e testes para um simulador de
   iPhone escolhido dinamicamente entre os instalados no runner, sem assinatura
   (`CODE_SIGNING_ALLOWED=NO`).
4. `ZebraRFIDManager.swift` aparece no log de compilação, e
   `ZebraSDKBuildTests` afirma em runtime que o framework entrou no build.
5. `xcodebuild test-without-building` roda a suíte inteira no simulador.

Se um dia o SDK virar binário só-device, o build de simulador quebra no passo 1.
A saída nesse caso é excluir o framework em simulador no `project.yml`
(`platforms`/`excludes` na dependência mais `EXCLUDED_ARCHS`) e documentar aqui
que o caminho Zebra deixou de ser coberto pelo CI.

## Testes

```sh
cd apps/ios
xcodegen generate
xcodebuild test -project EventPro.xcodeproj -scheme EventPro \
  -destination 'platform=iOS Simulator,name=iPhone 15' CODE_SIGNING_ALLOWED=NO
```

| Suíte | Cobre |
|---|---|
| `ContratosAPITests` | Fixtures de `docs/contratos-api.md` §2 a §8, incluindo as invariantes da conferência e a omissão dos campos aditivos |
| `ReturnViewModelTests` | D1: cobertura total, pendente virando `NAO_VOLTOU`, observação obrigatória, clamp de desgaste |
| `RfidTagNormalizerTests` | D2: normalização, validação e dedupe com ordem preservada |
| `APIClientTests` | D3 (recusa sem sessão), D9 (id minúsculo), sanitização anti-injeção, gap do vínculo |
| `RFIDManagerTests` | Ordem de leitura, `lastReadTag`, RSSI de pico, potência, erros tipados, troca mock/real |
| `ZebraSDKBuildTests` | O SDK real está no build |
| `SerialNumberTests`, `EquipmentTests`, `AuthServiceTests` | Modelos, depreciação, decode de data, expiração de sessão |

---

## O que não dá para garantir sem Mac e sem hardware

Este app foi escrito num ambiente Linux, sem Xcode. O CI cobre compilação e
testes; **nada abaixo está verificado**:

- **Comportamento do RFD40 real.** Descoberta MFi, handshake, gatilho físico,
  faixa de potência aceita, formato exato do EPC entregue por
  `srfidTagData.getTagId()` e cadência dos eventos de bateria. O simulador não
  tem acessório MFi.
- **Se `com.zebra.rfd8X00_easytext` basta para o RFD40 específico da MMD.**
  A string veio do binário do SDK e da documentação da Zebra, mas só o pareamento
  com o aparelho confirma.
- **Assinatura, provisioning e TestFlight.** Nunca exercitados: o CI roda sem
  assinatura de propósito.
- **Câmera.** O fluxo de permissão e a prévia AVFoundation não rodam no
  simulador do CI.
- **Keychain em device.** Os testes só leem (retorno nulo é caminho válido); a
  gravação real depende do app assinado.
- **Endpoints novos.** `/api/eventos/{id}/conferencia-rfid` e
  `/api/seriais/busca` ainda não existem no BFF: o cliente foi escrito contra a
  especificação de `docs/contratos-api.md` §7 e §8 e os testes validam só o
  decode das fixtures do documento.
- **Layout.** A UI é SwiftUI cru, sem design system, e será substituída na fase 7.
