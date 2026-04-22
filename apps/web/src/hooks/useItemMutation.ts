'use client'

import { useState } from 'react'
import { supabase } from '@/lib/supabase'

export type MutationError = { message: string }

export function useItemMutation() {
  const [pending, setPending] = useState<string | null>(null)
  const [error, setError] = useState<MutationError | null>(null)

  // Atualiza o desgaste (condição, 1-5) de TODOS os serial_numbers do item.
  // Simplificação fase 1.5: trata condição em nível de item. Fase 2 isola
  // desgaste por serial quando a UI de seriais estiver pronta.
  async function updateDesgaste(itemId: string, desgaste: number): Promise<boolean> {
    const clamped = Math.max(1, Math.min(5, Math.round(desgaste)))
    setPending(`condicao:${itemId}`)
    setError(null)
    try {
      const { error: err } = await supabase
        .from('serial_numbers')
        .update({ desgaste: clamped })
        .eq('item_id', itemId)
      if (err) {
        setError({ message: err.message })
        return false
      }
      return true
    } finally {
      setPending(null)
    }
  }

  async function updateQuantidade(itemId: string, qtd: number): Promise<boolean> {
    const clamped = Math.max(0, Math.round(qtd))
    setPending(`qtd:${itemId}`)
    setError(null)
    try {
      const { error: err } = await supabase
        .from('items')
        .update({ quantidade_total: clamped })
        .eq('id', itemId)
      if (err) {
        setError({ message: err.message })
        return false
      }
      return true
    } finally {
      setPending(null)
    }
  }

  return { updateDesgaste, updateQuantidade, pending, error }
}
