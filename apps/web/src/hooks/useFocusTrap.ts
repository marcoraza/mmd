'use client'

import { useEffect, type RefObject } from 'react'

// Selector WAI-ARIA padrão para elementos potencialmente focáveis. Filtros
// adicionais (visibilidade, disabled herdado) são aplicados em runtime
// abaixo, porque não dá pra exprimir tudo em selector CSS.
const FOCUSABLE_SELECTOR = [
  'a[href]',
  'area[href]',
  'input:not([disabled])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  'button:not([disabled])',
  'iframe',
  'object',
  'embed',
  '[tabindex]:not([tabindex="-1"])',
  '[contenteditable="true"]',
].join(',')

function isVisible(el: HTMLElement): boolean {
  // `offsetParent` é null pra elementos com display:none (e também pra
  // position:fixed que tem outras heurísticas). Para position:fixed
  // verificamos manualmente via getClientRects.
  if (el.offsetParent !== null) return true
  return el.getClientRects().length > 0
}

function getFocusable(container: HTMLElement): HTMLElement[] {
  const nodes = Array.from(container.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR))
  return nodes.filter((el) => !el.hasAttribute('disabled') && isVisible(el))
}

/**
 * Mantém o foco do teclado dentro do container enquanto o dialog está
 * aberto (WAI-ARIA Dialog focus trap).
 *
 * ⚠️ CRITICAL: RFID via Zebra RFD40 emula teclado, enviando o código de
 * barras como sequência de keystrokes seguida de Enter. Este hook intercepta
 * APENAS a tecla Tab (com e sem Shift). Letras, dígitos, Enter e qualquer
 * outra tecla passam direto pro input focado. Não altere isso sem revisar
 * o impacto no fluxo de leitura RFID que roda dentro de qualquer dialog
 * futuro.
 *
 * Comportamento:
 * 1. Ao montar com `enabled=true`, move foco pro primeiro focável dentro
 *    do container. Se não houver, foca o próprio container (precisa de
 *    tabIndex={-1} pra ser programaticamente focável).
 * 2. Tab no último focável → volta pro primeiro.
 * 3. Shift+Tab no primeiro → vai pro último.
 * 4. Se o foco "escapou" do container (ex: clique fora), Tab puxa o foco
 *    de volta pro primeiro.
 * 5. Set focável é recalculado em cada evento Tab, então conteúdo dinâmico
 *    (ex: <details> que expande) é coberto.
 *
 * @param containerRef ref do elemento que vira a fronteira do trap.
 * @param enabled quando false, hook é inerte. Use pra controlar abertura.
 */
export function useFocusTrap(
  containerRef: RefObject<HTMLElement | null>,
  enabled: boolean,
): void {
  useEffect(() => {
    if (!enabled) return
    const container = containerRef.current
    if (!container) return

    // Foco inicial. Tenta o primeiro focável; cai pro container se vazio.
    const focusables = getFocusable(container)
    if (focusables.length > 0) {
      focusables[0].focus({ preventScroll: true })
    } else if (container.hasAttribute('tabindex')) {
      container.focus({ preventScroll: true })
    }

    const handleKeyDown = (e: KeyboardEvent) => {
      // ⚠️ Só Tab. NUNCA filtrar outras teclas (RFID).
      if (e.key !== 'Tab') return

      const current = containerRef.current
      if (!current) return

      const items = getFocusable(current)
      if (items.length === 0) {
        // Sem focáveis: trava no container.
        e.preventDefault()
        if (current.hasAttribute('tabindex')) current.focus({ preventScroll: true })
        return
      }

      const first = items[0]
      const last = items[items.length - 1]
      const active = document.activeElement as HTMLElement | null

      // Foco escapou do container: puxa de volta pro primeiro.
      if (!active || !current.contains(active)) {
        e.preventDefault()
        first.focus({ preventScroll: true })
        return
      }

      if (e.shiftKey) {
        if (active === first) {
          e.preventDefault()
          last.focus({ preventScroll: true })
        }
      } else {
        if (active === last) {
          e.preventDefault()
          first.focus({ preventScroll: true })
        }
      }
    }

    // Listener no document pra capturar Tab mesmo se algum elemento
    // dentro do dialog fizer stopPropagation por engano.
    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [containerRef, enabled])
}
