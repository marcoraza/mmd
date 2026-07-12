'use client'

import { useEffect } from 'react'

/**
 * Snapshot do elemento focado na montagem e restauração no unmount.
 * Padrão WAI-ARIA Dialog: ao fechar um modal, o foco volta pro elemento
 * que abriu o modal (o trigger), pra que usuário de teclado e leitor de tela
 * não fique "perdido" no início do documento.
 *
 * Restauração é tolerante: se o elemento original já não está no DOM (por
 * exemplo, foi removido durante a sessão do dialog) ou não é focável,
 * silenciosamente não faz nada. O navegador então cai pro `document.body`.
 *
 * ## Contratos de uso
 *
 * Pra capturar o trigger correto, o snapshot precisa rodar ANTES de qualquer
 * outro efeito que mova o foco (ex: `useFocusTrap`). Declare `useReturnFocus`
 * acima de `useFocusTrap` no corpo do componente. React executa useEffects
 * na ordem de declaração; se inverter, o snapshot vai capturar um elemento
 * dentro do próprio dialog (que some no unmount) e o foco se perde.
 *
 * O snapshot acontece quando `enabled` transita de `false` pra `true` (ou
 * no mount se `enabled` já entrar como `true`). Padrões compatíveis:
 *
 *   ✓ Mount condicional do parent:
 *       {open && <Dialog />}   // hook recebe enabled=true no mount
 *
 *   ✓ Render sempre, hook reativo:
 *       <Dialog item={maybeItem} />
 *       function Dialog({ item }) {
 *         const open = item !== null
 *         useReturnFocus(open)
 *         if (!item) return null
 *       }
 *       // enabled flip false→true acontece no clique do trigger,
 *       // activeElement nesse instante é o trigger correto.
 *
 *   ✗ Anti-padrão (não suportado):
 *       useReturnFocus(open)  // open vira true por causa de timer/network
 *       // activeElement no momento do flip pode estar em qualquer lugar.
 *
 * @param enabled quando false, o hook é inerte. Permite condicionar ao
 *   estado de abertura do dialog.
 */
export function useReturnFocus(enabled: boolean): void {
  useEffect(() => {
    if (!enabled) return
    // Captura na montagem. `activeElement` é o elemento focado no momento em
    // que o dialog está prestes a tomar o foco.
    const previouslyFocused =
      typeof document !== 'undefined' ? (document.activeElement as HTMLElement | null) : null
    return () => {
      if (!previouslyFocused) return
      // Verifica se ainda está no DOM e se é focável (tem `.focus`).
      if (
        document.contains(previouslyFocused) &&
        typeof previouslyFocused.focus === 'function'
      ) {
        // `preventScroll: true` evita scroll inesperado quando o trigger
        // saiu da viewport durante a sessão do dialog.
        try {
          previouslyFocused.focus({ preventScroll: true })
        } catch {
          // Algum elemento exótico que não aceita focus(). Ignora.
        }
      }
    }
  }, [enabled])
}
