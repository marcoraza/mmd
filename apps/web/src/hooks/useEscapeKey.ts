'use client'

import { useEffect } from 'react'

/**
 * Dispara `onEscape` quando a tecla Escape é pressionada. Substitui o
 * useEffect inline que se repetia em 5 dialogs do app (ConflictModal,
 * CheckinDialog, CheckoutDialog, ItemSidePanel, UnitDrawer).
 *
 * Listener no `window` em vez do container do dialog porque a tecla Escape
 * deve fechar o dialog mesmo que o foco esteja fora dele (por exemplo, em
 * algum item do body que recebeu foco programaticamente). É consistente com
 * o padrão WAI-ARIA Dialog.
 *
 * @param enabled quando false, o listener não é registrado. Permite usar o
 *   hook condicionalmente sem violar a regra dos hooks. Útil quando o dialog
 *   é controlado por `null` props.
 * @param onEscape callback estável recomendado (useCallback) pra evitar
 *   re-registro do listener a cada render.
 */
export function useEscapeKey(enabled: boolean, onEscape: () => void): void {
  useEffect(() => {
    if (!enabled) return
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onEscape()
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [enabled, onEscape])
}
