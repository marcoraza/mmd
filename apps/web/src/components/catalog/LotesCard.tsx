import Link from 'next/link'
import { Icons } from '@/components/mmd/Icons'

export function LotesCard({ total }: { total: number }) {
  return (
    <Link
      href="/lotes"
      className="glass card-interactive"
      style={{
        marginTop: 20,
        padding: '18px 22px',
        display: 'flex',
        alignItems: 'center',
        gap: 16,
        borderRadius: 'var(--r-lg)',
      }}
    >
      <span
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          width: 44,
          height: 44,
          borderRadius: 'var(--r-md)',
          background: 'var(--accent-violet-soft)',
          color: 'var(--accent-violet)',
        }}
      >
        {Icons.package}
      </span>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          className="mono"
          style={{
            fontSize: 10,
            color: 'var(--fg-2)',
            letterSpacing: 0.1,
            textTransform: 'uppercase',
          }}
        >
          Lotes
        </div>
        <div style={{ fontSize: 16, fontWeight: 500, color: 'var(--fg-0)', marginTop: 2 }}>
          {total} lotes de cabos e agrupamentos
        </div>
        <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 2 }}>
          Cabos e consumíveis gerenciados por QR Code em grupos.
        </div>
      </div>
      <span style={{ color: 'var(--fg-2)' }}>{Icons.chevron_right}</span>
    </Link>
  )
}
