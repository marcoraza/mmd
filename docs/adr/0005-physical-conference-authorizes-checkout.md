---
status: proposed
---

# ADR 0005: Conferência física autoriza o check-out

O check-out deve receber e persistir a lista exata de unidades conferidas por RFID, QR Code ou confirmação manual. Apenas essas unidades mudam para `EM_CAMPO`; alocação sem leitura não prova saída, e uma confirmação incompleta não pode fabricar conferência. A UX usa uma única Conferência de saída por Evento, retomável e salva automaticamente, sem modelar veículos ou cargas. Qualquer operador autenticado pode confirmar uma saída incompleta com motivo curto e adicionar o restante depois. Essa decisão substitui o contrato atual, que movimenta todos os seriais alocados, e exige que app, API, auditoria e recibo compartilhem a mesma lista física.
