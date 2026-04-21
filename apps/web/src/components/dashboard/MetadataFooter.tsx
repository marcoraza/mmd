import type { OperationalPulse } from '@/lib/data/dashboard'

export function MetadataFooter({ operational }: { operational: OperationalPulse }) {
  return (
    <footer
      className="reveal reveal-4"
      style={{
        marginTop: 36,
        paddingTop: 18,
        borderTop: '1px solid var(--glass-border)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 16,
        flexWrap: 'wrap',
        color: 'var(--fg-3)',
        fontSize: 11,
      }}
    >
      <div className="mono" style={{ display: 'flex', gap: 18, flexWrap: 'wrap' }}>
        <span>
          <span style={{ color: 'var(--fg-0)', fontWeight: 500 }}>{operational.technicians_in_field}</span>{' '}
          <span style={{ color: 'var(--fg-2)' }}>TÉCNICOS EM CAMPO</span>
        </span>
        <span>
          <span style={{ color: 'var(--fg-0)', fontWeight: 500 }}>{operational.events_in_progress}</span>{' '}
          <span style={{ color: 'var(--fg-2)' }}>EVENTOS EM ANDAMENTO</span>
        </span>
        <span>
          <span style={{ color: 'var(--fg-2)' }}>PRÓXIMO CHECKOUT</span>{' '}
          <span style={{ color: 'var(--fg-0)', fontWeight: 500 }}>{operational.next_checkout_label}</span>
        </span>
      </div>
      <div className="mono" style={{ color: 'var(--fg-3)' }}>
        MMD ESTOQUE · v0.1.0
      </div>
    </footer>
  )
}
