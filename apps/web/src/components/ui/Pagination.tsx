'use client'

interface PaginationProps {
  page: number
  totalPages: number
  onPageChange: (page: number) => void
}

export function Pagination({ page, totalPages, onPageChange }: PaginationProps) {
  if (totalPages <= 1) return null

  const pages = Array.from({ length: totalPages }, (_, i) => i + 1)

  return (
    <div className="flex items-center gap-2 py-3">
      {pages.map((p) => (
        <button
          key={p}
          onClick={() => onPageChange(p)}
          style={{
            fontFamily: '"Space Mono", monospace',
            fontSize: 11,
            fontWeight: p === page ? 700 : 400,
            color: p === page ? '#000000' : '#999999',
            background: 'none',
            border: 'none',
            cursor: 'pointer',
            padding: '2px 6px',
            letterSpacing: '0.06em',
          }}
        >
          {String(p).padStart(2, '0')}
        </button>
      ))}
    </div>
  )
}
