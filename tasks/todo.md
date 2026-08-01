# Plano: treinamento privado do Marcelo

Goal ativo: consolidar `MAR-85`, `MAR-215`, `MAR-216`, `MAR-217`, `MAR-218`, `MAR-99`, `MAR-100`, `MAR-219` e `MAR-98` sem tratar mock como prova de hardware real.

## Estado observado em 17/07/2026

- Web: `npm install`, typecheck, lint, build e 108 testes passaram com o hub privado restaurado.
- iOS Release: build verde após corrigir a chamada estática em `AppConfig.swift:90`.
- iOS Debug: suíte completa verde, 91 testes, 0 falhas.
- Zebra: SPM oficial ligado ao target pelo commit `0d450520eb700a96e10e0dbd8d1c3e13eed5f111`; Debug Simulator e Release arm64 de aparelho compilam contra `ZebraRfidSdkFramework`.
- Zebra: o SPM oficial distribui o SDK 1.1.72; a documentação da Zebra lista 1.1.99 como atual e recomenda a última versão. Atualização exige baixar o XCFramework no portal da Zebra e aceitar os termos no próprio portal.
- Base de treino: `TRN-MARCELO-01` criada e verificada no Supabase com 5 unidades, 4 linhas e prontidão inicial 4/5.
- Hardware: o build Release de `MMD Estoque 1.0.0 (1)` foi assinado, instalado e aberto no iPhone físico `marko`; o processo permaneceu vivo após o primeiro launch.
- Hardware: RFD40 e tags estão com Marcelo; leitura real depende de coordenar o take físico com ele.

## Execução

1. Auditoria e blockers -> verificar Web com install, typecheck, lint, build e testes; verificar iOS Release, Debug, suíte completa, SDK Zebra, signing e disponibilidade do simulador/device.
2. Evento de treino -> criar preparação determinística com modo `probe` sem escrita, registros exclusivos de treinamento e restauração reversível; verificar plano antes/depois e repetição sem duplicar dados.
3. Web -> executar login, dashboard, catálogo, Evento, packing incompleto/completo, alocação, bloqueio, check-out, reflexo no dashboard, retorno OK/problema/não devolvido, QR público e auditoria; verificar cada capítulo isolado e depois o fluxo corrido.
4. iOS -> corrigir Release, religar a versão oficial do SDK Zebra de forma reproduzível e validar Debug/Release e suíte completa; verificar instalação assinada no iPhone físico e UI em `Zebra SDK`, nunca fallback.
5. RFD40 -> parear o leitor real e ler pelo menos 5 tags, incluindo uma conhecida e uma desconhecida; verificar persistência dos scans, check-out e retorno no backend real do Evento de treino.
6. Captação -> preparar shot log, estados iniciais reproduzíveis e capturas Web, iPhone e câmera externa; verificar cada take antes de editar e rotular qualquer simulação fora do corte final.
7. Showcases e hub -> produzir os tutoriais Web/iOS com o protocolo `raza-showcase`, usando capturas reais, anéis numerados, ação e resultado por cena; reunir as duas trilhas em `/treinamento`, `/treinamento/web` e `/treinamento/ios` com vídeos, progresso, versão, data e troubleshooting.
8. Entrega -> exportar master, cortes Web/iOS, vertical iOS, VTT, transcript, roteiro com timecodes, thumbnails e stills; verificar encode, áudio, legendas, ausência de secrets/dados pessoais e atualizar Linear com links e provas.
9. Handoff -> conduzir a primeira instalação e operação de Marcelo usando o hub, os showcases e os vídeos; verificar que ele repete o ciclo sem orientação externa e registrar a decisão sobre reinstalação assistida ou TestFlight.

## Progresso comprovado

- Gate Web: typecheck, lint e build verdes; suíte completa 108/108 e regra do Evento 8/8.
- Gate iOS: Release arm64 de aparelho verde; suíte Debug 91/91.
- Gate Zebra: teste `testProductionBuildLinksOfficialZebraSDK` impede regressão silenciosa para fallback.
- Gate Zebra: sem SDK, o runtime falha fechado e não emite leitores ou tags simuladas.
- Gate iPhone: app instalado e listado pelo aparelho como `com.emdash.mmdestoque`, versão `1.0.0`, build `1`.
- Gate iPhone: primeiro launch aceito pelo iOS após o trust; processo físico confirmado em execução.
- Gate Zebra no aparelho: usuário confirmou `Modo ativo: ZEBRA SDK` no Release físico.
- MAR-215: `scripts/prepare-training-event.ts --run 1` retornou `ready: true`, `writesPerformed: 0`.
- MAR-215: `--apply` sem confirmação foi recusado antes de qualquer escrita.
- MAR-215: apply autorizado criou 1 Evento e 4 linhas; retornou `apply-verified`, `writesPerformed: 5` e nenhuma mudança pendente.
- MAR-215: pós-check read-only confirmou `ready: true`, `exactChanges: []` e `writesPerformed: 0`.
- MAR-215: a execução 02 também produz plano válido sem reabrir ou apagar a execução anterior.
- MAR-215: restauração não destrutiva documentada; teste cobre ciclo 01 finalizado e ciclo 02 recriado em 4/5 sem reabrir histórico.
- MAR-99: hub, rotas, navegação e migration de progresso restaurados no Web.
- MAR-99: `/treinamento` mantém trilhas separadas de Web e iOS, capítulos, slots de vídeo, troubleshooting e progresso por usuário.
- MAR-217/MAR-218: o protocolo `raza-showcase` define capturas reais, anéis numerados, ação e resultado por cena nos tutoriais Web e iOS.
- MAR-217/MAR-218/MAR-219: plano de captação versionado com cenas, estados inicial/final, fontes e critérios de descarte.
- MAR-218: estado inicial real validado em sessão autenticada; Evento 4/5, gate bloqueado, desktop e 390x844 sem overflow, console limpo e nenhuma mutação feita pelo Browser.
- MAR-219: shot log criado; todos os takes permanecem `PENDENTE`, sem simulação contada como evidência.
- MAR-219: manifest e gate audiovisual criados; 5/5 testes cobrem capturas reais, rejeição de mock, mínimo de tags, resolução vertical e clipping.
- MAR-219: roteiro de locução por cena criado; transcript, VTT e timecodes continuam pendentes até o picture lock real.

## Gates humanos

- Confirmar antes de alterar dados reais fora do Evento de treino.
- Confirmar antes de deploy ou publicação de vídeo.
- Confirmar antes de qualquer compra, Apple Developer Program ou uso de SDK sem licença/origem oficial.
- Não marcar RFID como validado sem device, SDK, RFD40 e tags reais.
- O iPhone `marko` prova o build e o runtime; MAR-216 só fecha após instalação assistida no aparelho do Marcelo.
