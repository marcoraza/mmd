'use client'

import { useState } from 'react'
import { StatusBadge } from '@/components/ui/StatusBadge'
import { WearBar } from '@/components/ui/WearBar'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { ESTADO_LABELS, formatCurrencyFull } from '@/lib/design-tokens'
import type { SerialNumber } from '@/lib/types'

interface SerialNumberListProps {
  serials: SerialNumber[]
  onEdit?: (sn: SerialNumber) => void
  onDelete?: (id: string) => Promise<void>
}

export function SerialNumberList({ serials, onEdit, onDelete }: SerialNumberListProps) {
  const [deleteTarget, setDeleteTarget] = useState<string | null>(null)
  const [deleting, setDeleting] = useState(false)

  async function handleDelete() {
    if (!deleteTarget || !onDelete) return
    setDeleting(true)
    await onDelete(deleteTarget)
    setDeleting(false)
    setDeleteTarget(null)
  }

  return (
    <>
      <div style={{ overflowX: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ borderBottom: '1px solid #CCCCCC' }}>
              {['Código', 'Status', 'Estado', 'Desgaste', 'Valor Atual', ''].map((col) => (
                <th
                  key={col}
                  style={{
                    fontFamily: '"Space Mono", monospace',
                    fontSize: 9,
                    color: '#999999',
                    letterSpacing: '0.12em',
                    padding: '0 12px 8px',
                    textAlign: 'left',
                  }}
                >
                  {col.toUpperCase()}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {serials.map((sn) => (
              <tr key={sn.id} style={{ borderBottom: '1px solid #F0F0F0' }}>
                <td style={{ padding: '10px 12px', fontFamily: '"Space Mono", monospace', fontSize: 13, color: '#000000', fontWeight: 500 }}>
                  {sn.codigo_interno}
                  {sn.serial_fabrica && (
                    <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#CCCCCC', marginTop: 2 }}>
                      {sn.serial_fabrica}
                    </div>
                  )}
                </td>
                <td style={{ padding: '10px 12px' }}>
                  <StatusBadge status={sn.status} />
                </td>
                <td style={{ padding: '10px 12px', fontFamily: '"Space Mono", monospace', fontSize: 10, color: '#666666', letterSpacing: '0.06em' }}>
                  {(ESTADO_LABELS[sn.estado] ?? sn.estado).toUpperCase()}
                </td>
                <td style={{ padding: '10px 12px' }}>
                  <WearBar desgaste={sn.desgaste} />
                </td>
                <td style={{ padding: '10px 12px', fontFamily: '"Space Mono", monospace', fontSize: 12, color: '#666666' }}>
                  {sn.valor_atual ? formatCurrencyFull(sn.valor_atual) : '—'}
                </td>
                <td style={{ padding: '10px 12px' }}>
                  <div className="flex items-center gap-3">
                    {onEdit && (
                      <button
                        onClick={() => onEdit(sn)}
                        style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', background: 'none', border: 'none', cursor: 'pointer', letterSpacing: '0.08em' }}
                      >
                        EDITAR
                      </button>
                    )}
                    {onDelete && sn.status === 'DISPONIVEL' && (
                      <button
                        onClick={() => setDeleteTarget(sn.id)}
                        style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#D71921', background: 'none', border: 'none', cursor: 'pointer', letterSpacing: '0.08em' }}
                      >
                        EXCLUIR
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {serials.length === 0 && (
          <div style={{ padding: '24px', fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#CCCCCC', textAlign: 'center' }}>
            NENHUM SERIAL CADASTRADO
          </div>
        )}
      </div>
      <ConfirmDialog
        open={!!deleteTarget}
        title="Excluir serial number?"
        description="Esta ação não pode ser desfeita."
        confirmLabel="Excluir"
        danger
        onConfirm={handleDelete}
        onCancel={() => setDeleteTarget(null)}
      />
    </>
  )
}
