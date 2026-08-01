'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import type { TrainingProgressActionResult } from '@/lib/actions/training-progress'

type Action = (formData: FormData) => Promise<TrainingProgressActionResult>

export function TrainingChapterToggle({
  action,
  completed,
  disabled,
}: {
  action: Action
  completed: boolean
  disabled: boolean
}) {
  const [state, formAction] = useActionState(
    async (_previous: TrainingProgressActionResult | null, formData: FormData) => action(formData),
    null,
  )

  return (
    <form action={formAction} style={{ display: 'grid', justifyItems: 'end', gap: 6 }}>
      <SubmitButton completed={completed} disabled={disabled} />
      {state && !state.ok && (
        <span role="alert" style={{ color: 'var(--accent-red)', fontSize: 11, maxWidth: 220 }}>
          {state.error}
        </span>
      )}
    </form>
  )
}

function SubmitButton({ completed, disabled }: { completed: boolean; disabled: boolean }) {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={disabled || pending}
      aria-pressed={completed}
      style={{
        border: '1px solid var(--glass-border-strong)',
        borderRadius: 8,
        background: completed ? 'var(--accent-green-soft)' : 'var(--glass-bg)',
        color: completed ? 'var(--accent-green)' : 'var(--fg-1)',
        padding: '8px 11px',
        fontFamily: 'var(--font-sans-raw)',
        fontSize: 12,
        fontWeight: 600,
        cursor: disabled || pending ? 'not-allowed' : 'pointer',
        opacity: disabled ? 0.45 : 1,
      }}
    >
      {pending ? 'Salvando' : completed ? 'Concluído' : 'Marcar concluído'}
    </button>
  )
}
