'use client'

interface ConfirmDialogProps {
  open: boolean
  title: string
  description?: string
  confirmLabel?: string
  cancelLabel?: string
  onConfirm: () => void
  onCancel: () => void
  danger?: boolean
}

export function ConfirmDialog({
  open,
  title,
  description,
  confirmLabel = 'Confirmar',
  cancelLabel = 'Cancelar',
  onConfirm,
  onCancel,
  danger = false,
}: ConfirmDialogProps) {
  if (!open) return null

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center"
      style={{ backgroundColor: 'rgba(0,0,0,0.8)' }}
      onClick={onCancel}
    >
      <div
        className="relative p-6 min-w-[320px] max-w-md"
        style={{ backgroundColor: '#FFFFFF', border: '1px solid #E8E8E8' }}
        onClick={(e) => e.stopPropagation()}
      >
        <h3
          style={{
            fontFamily: '"Space Grotesk", sans-serif',
            fontSize: 16,
            fontWeight: 600,
            color: '#000000',
            marginBottom: 8,
          }}
        >
          {title}
        </h3>
        {description && (
          <p
            style={{
              fontFamily: '"Space Grotesk", sans-serif',
              fontSize: 14,
              color: '#666666',
              marginBottom: 24,
            }}
          >
            {description}
          </p>
        )}
        <div className="flex gap-3 justify-end">
          <button
            onClick={onCancel}
            style={{
              fontFamily: '"Space Mono", monospace',
              fontSize: 11,
              letterSpacing: '0.08em',
              color: '#666666',
              border: '1px solid #CCCCCC',
              background: 'none',
              borderRadius: 999,
              padding: '6px 16px',
              cursor: 'pointer',
            }}
          >
            {cancelLabel.toUpperCase()}
          </button>
          <button
            onClick={onConfirm}
            style={{
              fontFamily: '"Space Mono", monospace',
              fontSize: 11,
              letterSpacing: '0.08em',
              color: danger ? '#FFFFFF' : '#FFFFFF',
              backgroundColor: danger ? '#D71921' : '#000000',
              border: 'none',
              borderRadius: 999,
              padding: '6px 16px',
              cursor: 'pointer',
            }}
          >
            {confirmLabel.toUpperCase()}
          </button>
        </div>
      </div>
    </div>
  )
}
