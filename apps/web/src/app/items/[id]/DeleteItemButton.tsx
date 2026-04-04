'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabase'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'

interface DeleteItemButtonProps {
  itemId: string
  hasSerials: boolean
}

export function DeleteItemButton({ itemId, hasSerials }: DeleteItemButtonProps) {
  const router = useRouter()
  const [open, setOpen] = useState(false)
  const [loading, setLoading] = useState(false)

  async function handleDelete() {
    setLoading(true)
    const { error } = await supabase.from('items').delete().eq('id', itemId)
    setLoading(false)
    if (!error) router.push('/items')
  }

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        disabled={loading}
        style={{
          fontFamily: '"Space Mono", monospace',
          fontSize: 11,
          letterSpacing: '0.1em',
          color: '#D71921',
          border: '1px solid #D71921',
          borderRadius: 999,
          padding: '6px 14px',
          background: 'none',
          cursor: 'pointer',
        }}
      >
        EXCLUIR
      </button>
      <ConfirmDialog
        open={open}
        title="Excluir item?"
        description={
          hasSerials
            ? 'Este item possui serial numbers associados. Todos serão excluídos permanentemente.'
            : 'Esta ação não pode ser desfeita.'
        }
        confirmLabel="Excluir"
        danger
        onConfirm={handleDelete}
        onCancel={() => setOpen(false)}
      />
    </>
  )
}
