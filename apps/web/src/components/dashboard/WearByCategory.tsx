import { CATEGORIA_LABELS, WEAR_COLORS } from '@/lib/design-tokens'
import type { CategoriaStats } from '@/lib/types'

interface WearByCategoryProps {
  data: CategoriaStats[]
}

export function WearByCategory({ data }: WearByCategoryProps) {
  return (
    <div style={{ padding: '20px 24px', borderRight: '1px solid #E8E8E8' }}>
      <div style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#999999', letterSpacing: '0.12em', marginBottom: 16 }}>
        DESGASTE POR CATEGORIA
      </div>
      <div className="flex flex-col gap-3">
        {data.map((d) => {
          const desgaste = d.desgaste_medio ?? 3
          const color = WEAR_COLORS[Math.round(desgaste)] ?? '#FFFFFF'
          return (
            <div key={d.categoria} className="flex items-center gap-3">
              <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 9, color: '#666666', width: 52, letterSpacing: '0.06em' }}>
                {(CATEGORIA_LABELS[d.categoria] ?? d.categoria).substring(0, 5).toUpperCase()}
              </span>
              <div className="flex items-center gap-[2px] flex-1">
                {[1, 2, 3, 4, 5].map((i) => (
                  <div
                    key={i}
                    style={{
                      flex: 1, height: 5,
                      backgroundColor: i <= Math.round(desgaste) ? color : '#E8E8E8',
                    }}
                  />
                ))}
              </div>
              <span style={{ fontFamily: '"Space Mono", monospace', fontSize: 11, color, fontWeight: 700, width: 24, textAlign: 'right' }}>
                {desgaste.toFixed(1)}
              </span>
            </div>
          )
        })}
      </div>
    </div>
  )
}
