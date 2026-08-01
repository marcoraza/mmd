# Plano de captação do treinamento MMD

Versão: `0.1.0-draft`  
Data do plano: `17/07/2026`  
Evento exclusivo: `Treinamento · Marcelo`

Este plano separa prova operacional de material explicativo. Um take só entra no corte final quando mostra o produto real, parte do estado inicial registrado e termina com um resultado verificável.

## Gate antes da gravação final

- [x] Build Release assinado e instalado no iPhone físico.
- [x] SDK Zebra oficial ligado e protegido contra fallback silencioso.
- [x] Hub privado restaurado e validado em desktop e mobile.
- [ ] Migration de progresso aprovada, aplicada e validada com usuário autenticado.
- [ ] Perfil `Marco Rangel` confiado no iPhone e primeiro launch concluído.
- [ ] Tela Ajustes mostrando `Modo ativo: ZEBRA SDK`.
- [ ] Evento `Treinamento · Marcelo` aplicado após confirmação.
- [ ] RFD40 real descoberto e conectado.
- [ ] Cinco tags físicas lidas, incluindo conhecida e desconhecida.
- [ ] Relatório do Evento salvo antes do primeiro take.
- [ ] Não Perturbe ativo e superfícies sem notificações, secrets ou dados pessoais.

Se qualquer item pendente impedir a ação mostrada, o take fica fora do corte final. Mock pode servir para ensaio identificado como `SIMULAÇÃO`, nunca como prova.

## Fontes

| Código | Fonte | Configuração | Uso |
|---|---|---|---|
| `WEB` | Chrome limpo | 2560x1440, zoom 100%, captura 60 fps | Gestão completa do Evento |
| `IOS` | Tela do iPhone via QuickTime | resolução nativa, cabo USB | Resposta do app |
| `CAM` | Câmera externa | 4K, 30 fps, shutter 1/60, foco e exposição travados | RFD40, gatilho, tags e distância |

No começo de cada take iOS, fazer um toque visível que apareça em `IOS` e `CAM`. O beep preservado precisa vir do leitor real.

## Convenção de arquivos

```text
YYYYMMDD-WEB-capitulo-takeNN.mov
YYYYMMDD-IOS-capitulo-takeNN.mov
YYYYMMDD-CAM-capitulo-takeNN.mov
```

Cada take registra duração, estado inicial, estado final e decisão `usar` ou `descartar` em `shot-log.md`.

## Instalação assistida, MAR-216

| Cena | Ação visível | Estado inicial | Prova de saída |
|---|---|---|---|
| `INS-01` | Mostrar aparelho selecionado e build Release concluído | iPhone pareado, app fechado | Build assinado sem secret visível |
| `INS-02` | Instalar `MMD Estoque` | app ausente ou versão anterior | app `1.0.0 (1)` listado no aparelho |
| `INS-03` | Confiar no perfil de desenvolvimento | launch recusado pelo iOS | app abre no iPhone |
| `INS-04` | Entrar com conta MMD | app sem sessão | sessão ativa sem senha exposta |
| `INS-05` | Abrir Ajustes e mostrar o modo | leitor simulado desligado | `Modo ativo: ZEBRA SDK` |

Fecho falado depois do picture lock: assinatura pessoal pode expirar em cerca de sete dias. TestFlight só entra como decisão posterior, não como recurso já disponível.

## Operação iOS, MAR-217

| Cena | Ação visível | Estado inicial | Prova de saída |
|---|---|---|---|
| `IOS-01` | Preparar, parear e descobrir o RFD40 | leitor desligado e app desconectado | nome real do leitor aparece |
| `IOS-02` | Conectar o leitor | RFD40 descoberto | estado conectado e bateria quando disponível |
| `IOS-03` | Ler tag conhecida | lista de leituras vazia | unidade correta aberta pelo EPC real |
| `IOS-04` | Ler tag desconhecida | tag sem vínculo separada | tag registrada para tratamento, sem descarte |
| `IOS-05` | Ler lote de pelo menos cinco tags | Evento aberto, packing incompleto | faltantes e extras coerentes com as tags físicas |
| `IOS-06` | Concluir check-out | packing completo e gate liberado | saída confirmada no app |
| `IOS-07` | Provar persistência | saída recém-confirmada | Web ou backend mostra a movimentação |
| `IOS-08` | Retornar unidade OK | unidade em campo | retorno OK persistido |
| `IOS-09` | Retornar item com problema ou pendência | segunda unidade em campo | pendência visível e explicada |
| `IOS-10` | Usar QR como fallback | RFID indisponível de forma explícita | mesma unidade resolvida pelo QR |
| `IOS-11` | Recuperar desconexão, leitura vazia e sessão expirada | falha controlada por vez | ação segura restaura o fluxo |

## Operação Web, MAR-218

| Cena | Ação visível | Estado inicial | Prova de saída |
|---|---|---|---|
| `WEB-01` | Login e leitura do dashboard | sem sessão | dashboard autenticado, sem senha visível |
| `WEB-02` | Localizar item e abrir unidade | catálogo aberto | diferença entre tipo e peça física compreensível |
| `WEB-03` | Abrir `Treinamento · Marcelo` | Evento confirmado | ficha, cliente, local e datas de treino visíveis |
| `WEB-04` | Revisar packing e divergência | prontidão abaixo de 100% | causa do bloqueio identificada |
| `WEB-05` | Alocar unidade e resolver pendência | uma unidade faltante | packing completo e gate liberado |
| `WEB-06` | Acompanhar check-out | saída acabando de ocorrer | status e dashboard atualizados sem corte enganoso |
| `WEB-07` | Acompanhar retorno | unidades em campo | OK, problema e não devolvido diferenciados |
| `WEB-08` | Abrir QR público | unidade do treinamento | ficha mínima sem valor, RFID ou histórico privado |
| `WEB-09` | Consultar auditoria | ciclo encerrado | operador, horário e movimentações visíveis |

## Montagem, MAR-219

O picture lock vem antes da narração. A edição usa as cenas aprovadas dos showcases Web e iOS. O protocolo `raza-showcase` organiza capturas, destaques numerados e texto por cena sem transformar o tutorial em apresentação de marketing.

| Arquivo | Alvo | Conteúdo |
|---|---:|---|
| `mmd-treinamento-master.mp4` | 25-35 min | introdução, Web, passagem para campo, iOS e fecho |
| `mmd-showcase-web.mp4` | 10-15 min | `WEB-01` a `WEB-09` |
| `mmd-showcase-ios.mp4` | 12-18 min | `INS-03` a `INS-05` e `IOS-01` a `IOS-11` |
| `mmd-showcase-ios-vertical.mp4` | 1080x1920 | operação iOS sem miniaturizar a interface |

Cada export exige VTT pt-BR, transcript Markdown, capítulos com timecodes, thumbnail, stills, áudio sem clipping e revisão visual de dados pessoais.

## Gate executável da entrega

`delivery-manifest.json` acompanha as 24 capturas obrigatórias e os quatro exports. Cada captura aprovada registra arquivo, origem real, revisão de privacidade e SHA-256. Cenas operacionais também registram o código `TRN-MARCELO-NN` usado no take.

```bash
python3 scripts/validate-training-delivery.py
```

O comando só termina com sucesso quando comprova RFD40 real, pelo menos cinco tags com conhecida e desconhecida, fallback por QR, persistência das ações e todos os arquivos finais. Os exports precisam ter vídeo H.264, áudio AAC com pico máximo de -1 dBFS, resolução e duração aprovadas, VTT, transcript, timecodes e thumbnail.

Enquanto as capturas estiverem pendentes, a saída diferente de zero é o comportamento correto. Mock e arquivo identificado como simulação são recusados como evidência.

## Pronúncia para revisão

Antes de gerar a voz final, revisar em amostra curta: `MMD`, `RFD40`, `RFID`, `packing`, `check-out`, `QR`, `Zebra` e `Marcelo`.
