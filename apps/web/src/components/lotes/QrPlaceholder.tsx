/**
 * Placeholder QR visual. Gera um pattern determinístico a partir do código do
 * lote, só pra preencher o hero enquanto a geração real (task /qrcodes) não
 * chega. Inclui os três finder patterns clássicos de QR e um grid ruidoso no
 * meio.
 */
export function QrPlaceholder({
  value,
  size = 200,
}: {
  value: string
  size?: number
}) {
  const modules = 25 // grid de 25x25
  const cell = size / modules
  const seed = hash(value || 'lote')

  const cells: { x: number; y: number }[] = []
  for (let y = 0; y < modules; y++) {
    for (let x = 0; x < modules; x++) {
      if (isFinderArea(x, y, modules)) continue
      // pattern determinístico baseado em seed + posição
      const n = ((seed + x * 73 + y * 151) >>> 0) % 100
      if (n < 48) cells.push({ x, y })
    }
  }

  return (
    <svg
      width={size}
      height={size}
      viewBox={`0 0 ${size} ${size}`}
      role="img"
      aria-label={`QR placeholder para ${value}`}
      style={{
        background: 'var(--bg-0)',
        borderRadius: 'var(--r-sm)',
        padding: 8,
        boxSizing: 'content-box',
      }}
    >
      {/* Fundo branco para contraste */}
      <rect x={0} y={0} width={size} height={size} fill="#fff" />

      {/* Módulos aleatórios (fora das áreas dos finders) */}
      {cells.map((c, i) => (
        <rect
          key={i}
          x={c.x * cell}
          y={c.y * cell}
          width={cell}
          height={cell}
          fill="#000"
        />
      ))}

      {/* Finder patterns: top-left, top-right, bottom-left */}
      <FinderPattern x={0} y={0} cell={cell} />
      <FinderPattern x={(modules - 7) * cell} y={0} cell={cell} />
      <FinderPattern x={0} y={(modules - 7) * cell} cell={cell} />
    </svg>
  )
}

function FinderPattern({ x, y, cell }: { x: number; y: number; cell: number }) {
  const outer = 7 * cell
  const mid = 5 * cell
  const inner = 3 * cell
  return (
    <g>
      <rect x={x} y={y} width={outer} height={outer} fill="#000" />
      <rect x={x + cell} y={y + cell} width={mid} height={mid} fill="#fff" />
      <rect x={x + 2 * cell} y={y + 2 * cell} width={inner} height={inner} fill="#000" />
    </g>
  )
}

function isFinderArea(x: number, y: number, modules: number): boolean {
  // top-left
  if (x < 8 && y < 8) return true
  // top-right
  if (x >= modules - 8 && y < 8) return true
  // bottom-left
  if (x < 8 && y >= modules - 8) return true
  return false
}

function hash(s: string): number {
  let h = 2166136261
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return h >>> 0
}
