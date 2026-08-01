# Shot log do treinamento MMD

Preencher uma linha por arquivo capturado. Estado inicial e final precisam ser verificáveis. Arquivo sem esses dois campos não entra no corte.

| Arquivo | Cena | Fonte | Duração | Estado inicial | Estado final | Privacidade | Decisão | Observações |
|---|---|---|---:|---|---|---|---|---|
| PENDENTE | `INS-03` | `IOS` |  | launch bloqueado pelo perfil | app aberto | revisar | pendente | exige gesto no iPhone |
| PENDENTE | `INS-04` | `IOS` |  | app sem sessão | sessão MMD ativa | revisar | pendente | senha fora da captura |
| PENDENTE | `INS-05` | `IOS` |  | Ajustes fechado | modo Zebra SDK visível | revisar | pendente | fallback não serve como prova |
| PENDENTE | `IOS-01` | `IOS` |  | RFD40 desligado | leitor descoberto | revisar | pendente | sincronizar com `CAM` |
| PENDENTE | `IOS-01` | `CAM` |  | RFD40 desligado | leitor descoberto | revisar | pendente | preservar beep real |
| PENDENTE | `IOS-02` | `IOS` |  | RFD40 descoberto | leitor conectado | revisar | pendente | mostrar bateria quando disponível |
| PENDENTE | `IOS-03` | `IOS` |  | zero tags na sessão | unidade conhecida aberta | revisar | pendente | EPC mascarado na edição se necessário |
| PENDENTE | `IOS-04` | `IOS` |  | tag sem vínculo | tratamento registrado | revisar | pendente | não simular desconhecida |
| PENDENTE | `IOS-05` | `IOS` |  | packing incompleto | cinco tags físicas conferidas | revisar | pendente | contagem mínima obrigatória |
| PENDENTE | `IOS-06` | `IOS` |  | gate liberado | check-out confirmado | revisar | pendente | Evento de treino apenas |
| PENDENTE | `IOS-07` | `WEB` |  | saída recém-confirmada | movimentação persistida | revisar | pendente | sem DevTools |
| PENDENTE | `IOS-08` | `IOS` |  | unidade em campo | retorno OK | revisar | pendente |  |
| PENDENTE | `IOS-09` | `IOS` |  | unidade em campo | pendência criada | revisar | pendente |  |
| PENDENTE | `IOS-10` | `IOS` |  | RFID indisponível declarado | unidade resolvida por QR | revisar | pendente | diferenciar QR de RFID |
| PENDENTE | `IOS-11` | `IOS` |  | falha controlada ativa | fluxo recuperado com ação segura | revisar | pendente | uma falha por take |
| PENDENTE | `WEB-01` | `WEB` |  | sem sessão | dashboard autenticado | revisar | pendente | senha fora da captura |
| PENDENTE | `WEB-02` | `WEB` |  | catálogo aberto | unidade física aberta | revisar | pendente | explicar Item e Serial Number |
| PENDENTE | `WEB-03` | `WEB` |  | lista de Eventos | Evento de treino aberto | revisar | pendente | dados exclusivos de treino |
| PENDENTE | `WEB-04` | `WEB` |  | prontidão incompleta | causa identificada | revisar | pendente |  |
| PENDENTE | `WEB-05` | `WEB` |  | divergência ativa | gate liberado | revisar | pendente |  |
| PENDENTE | `WEB-06` | `WEB` |  | antes da saída | dashboard atualizado | revisar | pendente | sem corte entre ação e reflexo |
| PENDENTE | `WEB-07` | `WEB` |  | unidades em campo | retorno conferido | revisar | pendente |  |
| PENDENTE | `WEB-08` | `WEB` |  | ficha privada | QR público mínimo | revisar | pendente | confirmar ausência de valor e RFID |
| PENDENTE | `WEB-09` | `WEB` |  | ciclo encerrado | auditoria aberta | revisar | pendente | operador e horário do treino |

## Motivos de descarte

- mock, fallback ou beep inserido aparecendo como prova física
- notificação, senha, token, cookie, service role ou dado pessoal visível
- estado inicial desconhecido
- resultado final não persistido
- frame drop, foco perdido ou tela ilegível
- ação importante sem pausa de edição antes e depois
