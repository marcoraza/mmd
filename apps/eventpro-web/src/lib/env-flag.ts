// Leitura de flag booleana vinda de variável de ambiente.
//
// Vive num módulo próprio porque três camadas independentes precisam da mesma
// interpretação: `auth-config` (bypass de desenvolvimento), `readonly` (bloqueio
// de escrita) e qualquer configuração futura. No legado a função morava dentro
// de `demo-mode-core`, módulo que não existe no EventPro (não há modo demo).

export function envFlag(value: string | undefined) {
  if (!value) return null
  const normalized = value.trim().toLowerCase()
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false
  return null
}
