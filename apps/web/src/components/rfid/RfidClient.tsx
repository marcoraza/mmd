'use client'

import { useMemo, useState } from 'react'
import { Icons } from '@/components/mmd/Icons'
import type { RfidData } from '@/lib/data/rfid'
import { ReaderCard } from './ReaderCard'
import { RfidBanner, type RfidBannerFilter } from './RfidBanner'
import { ScanTimeline } from './ScanTimeline'

export function RfidClient({ data }: { data: RfidData }) {
  const [banner, setBanner] = useState<RfidBannerFilter>(null)
  const [readerFilter, setReaderFilter] = useState<string>('ALL')
  const [query, setQuery] = useState('')

  const filtered = useMemo(() => {
    const now = Date.now()
    const ms24h = 24 * 60 * 60 * 1000
    const startOfDay = new Date()
    startOfDay.setHours(0, 0, 0, 0)
    const startOfDayMs = startOfDay.getTime()
    const q = query.trim().toLowerCase()

    return data.scans.filter((s) => {
      if (readerFilter !== 'ALL' && s.reader_id !== readerFilter) return false

      const t = new Date(s.timestamp).getTime()
      if (banner === 'hoje' && t < startOfDayMs) return false
      if (banner === '24h' && now - t > ms24h) return false
      if (banner === 'orfas') {
        if (s.reconhecido) return false
        if (now - t > ms24h) return false
      }

      if (q) {
        const haystack = [
          s.tag_rfid,
          s.operador,
          s.reader_nome,
          s.localizacao,
          s.serial_codigo,
          s.lote_codigo,
          s.item_nome,
          s.projeto_nome,
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase()
        if (!haystack.includes(q)) return false
      }
      return true
    })
  }, [data.scans, banner, readerFilter, query])

  return (
    <>
      <RfidBanner
        stats={data.banner}
        active={banner}
        onFilter={(f) => setBanner((prev) => (prev === f ? null : f))}
      />

      {/* Toolbar */}
      <div
        style={{
          marginTop: 20,
          display: 'flex',
          gap: 12,
          alignItems: 'center',
          flexWrap: 'wrap',
          padding: '14px 18px',
          border: '1px solid var(--glass-border)',
          borderRadius: 'var(--r-md)',
          background: 'var(--glass-bg)',
          backdropFilter: 'blur(18px) saturate(160%)',
          WebkitBackdropFilter: 'blur(18px) saturate(160%)',
        }}
      >
        <label
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            flex: '1 1 280px',
            padding: '8px 12px',
            border: '1px solid var(--glass-border)',
            borderRadius: 'var(--r-sm)',
            background: 'var(--bg-0)',
            color: 'var(--fg-2)',
          }}
        >
          {Icons.search}
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Buscar por tag, operador, item, projeto..."
            style={{
              flex: 1,
              background: 'transparent',
              border: 'none',
              outline: 'none',
              color: 'var(--fg-0)',
              fontFamily: 'inherit',
              fontSize: 13,
            }}
          />
        </label>

        <select
          value={readerFilter}
          onChange={(e) => setReaderFilter(e.target.value)}
          style={{
            padding: '7px 12px',
            borderRadius: 'var(--r-sm)',
            border: '1px solid var(--glass-border)',
            background: 'var(--bg-0)',
            color: 'var(--fg-1)',
            fontFamily: 'inherit',
            fontSize: 12,
            cursor: 'pointer',
          }}
        >
          <option value="ALL">Todos os leitores</option>
          {data.readers.map((r) => (
            <option key={r.id} value={r.id}>
              {r.nome}
            </option>
          ))}
        </select>

        <div
          className="mono"
          style={{
            fontSize: 11,
            color: 'var(--fg-2)',
            letterSpacing: 0.1,
            textTransform: 'uppercase',
          }}
        >
          {filtered.length} / {data.scans.length}
        </div>
      </div>

      {/* Main grid */}
      <div
        style={{
          marginTop: 16,
          display: 'grid',
          gridTemplateColumns: 'minmax(0, 1fr) minmax(280px, 340px)',
          gap: 16,
          alignItems: 'start',
        }}
      >
        <div style={{ minWidth: 0 }}>
          <SectionHeader title="Timeline de scans" hint="Últimas 200 leituras" />
          <div style={{ marginTop: 8 }}>
            <ScanTimeline scans={filtered} />
          </div>
        </div>

        <div style={{ minWidth: 0 }}>
          <SectionHeader
            title="Leitores pareados"
            hint={`${data.readers.length} registrados`}
          />
          <div
            style={{
              marginTop: 8,
              display: 'flex',
              flexDirection: 'column',
              gap: 10,
            }}
          >
            {data.readers.length === 0 ? (
              <div
                style={{
                  padding: 18,
                  border: '1px dashed var(--glass-border)',
                  borderRadius: 'var(--r-md)',
                  fontSize: 12,
                  color: 'var(--fg-3)',
                }}
              >
                Nenhum leitor cadastrado. Paream no app iOS pra aparecerem aqui.
              </div>
            ) : (
              data.readers.map((r) => <ReaderCard key={r.id} reader={r} />)
            )}
          </div>
        </div>
      </div>
    </>
  )
}

function SectionHeader({ title, hint }: { title: string; hint?: string }) {
  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'baseline',
        gap: 12,
      }}
    >
      <div
        className="mono"
        style={{
          fontSize: 10,
          color: 'var(--fg-2)',
          letterSpacing: 0.12,
          textTransform: 'uppercase',
        }}
      >
        {title}
      </div>
      {hint && (
        <div style={{ fontSize: 11, color: 'var(--fg-3)' }}>{hint}</div>
      )}
    </div>
  )
}
