# ZebraRfidSdkFramework.xcframework (vendorizado)

## Origem

| Campo | Valor |
|---|---|
| Repositório oficial | `https://github.com/ZebraDevs/alt-rfid-ios-sdk` |
| Pod CocoaPods | `ZebraRfidiOSSdk` (podspec `ZebraRfidiOSSdk.podspec`, `s.version = '0.1.10'`) |
| Commit clonado | `0d450520eb700a96e10e0dbd8d1c3e13eed5f111` (branch `main`, 2024-08-23) |
| Caminho no repo | `FrameworkScannerAndRfidSDK/RFIDFramework/ZebraRfidSdkFramework.xcframework` |
| Versão do SDK | `1.1.72` (o repo publica o mesmo binário em `iOS_SPM/v.1.1.72/`) |
| Data de vendorização | 2026-08-05 |
| Licença | `LICENSE-Zebra.md` (Zebra Technologies, redistribuição do binário permitida ao integrador) |

O binário é byte a byte idêntico nas três cópias que o repo publica
(`FrameworkScannerAndRfidSDK/`, `Zebra123RFIDsdkSPM/Frameworks/`, `iOS_SPM/v.1.1.72/`), e a tag mais
recente do repo (`0.1.14`) carrega o mesmo binário do `main`.

## Hashes

```
sha256  994226ecfee06a3a8e5a65a3101ead50f5f6ca9394c0bd01cf169b2f3b393678
        ios-arm64/ZebraRfidSdkFramework.framework/ZebraRfidSdkFramework

sha256  e715ecf67322009825845962b373eae5aadc0b2d093b539f5b0ba89052e0f5df
        ios-arm64_x86_64-simulator/ZebraRfidSdkFramework.framework/ZebraRfidSdkFramework
```

## Slices

| LibraryIdentifier | Arquiteturas | Plataforma |
|---|---|---|
| `ios-arm64` | arm64 | iOS device |
| `ios-arm64_x86_64-simulator` | arm64, x86_64 | iOS Simulator |

**Existe slice de simulador.** É por isso que o CI (macos-14, `xcodebuild ... -destination
'platform=iOS Simulator'`) consegue compilar `ZebraRFIDManager.swift` de verdade, e não só o caminho
mock. `MinimumOSVersion` do framework é 14.0, abaixo do deployment target 16.0 do app.

Os headers públicos são idênticos nos dois slices (verificado com `diff -rq`), então o módulo
`ZebraRfidSdkFramework` (`Modules/module.modulemap`, umbrella `ZebraRfidSdkFramework.h`) expõe a
mesma API nos dois.

## Como atualizar

```sh
git clone --depth 1 https://github.com/ZebraDevs/alt-rfid-ios-sdk.git /tmp/zebra-sdk
rm -rf apps/ios/Vendor/ZebraRfidSdkFramework/ZebraRfidSdkFramework.xcframework
cp -R /tmp/zebra-sdk/FrameworkScannerAndRfidSDK/RFIDFramework/ZebraRfidSdkFramework.xcframework \
      apps/ios/Vendor/ZebraRfidSdkFramework/
find apps/ios/Vendor -name .DS_Store -delete
```

Depois: atualizar commit, versão e hashes acima, e conferir se as assinaturas usadas em
`EventPro/Services/ZebraRFIDManager.swift` continuam válidas (`Headers/RfidSdkApi.h`,
`Headers/RfidSdkApiDelegate.h`, `Headers/RfidSdkDefs.h`).

## Não vendorizado de propósito

`ZebraScannerFramework.xcframework` (pod `ZebraBarcodeiOSSdk`) fica de fora: o EventPro usa
AVFoundation para QR, não o scanner de código de barras da Zebra.
