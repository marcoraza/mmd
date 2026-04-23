// conflict-resolver.jsx — resolve a date/qty conflict on the calendar

function ConflictResolver() {
  // Context: Feira Construção SP needs 20 Par LED, but only 12 are free
  // on those dates. 4 units are still packed from Casamento Santos,
  // 4 are being repaired.

  const options = [
    {
      id: 'alt-model',
      label: 'Usar modelo alternativo',
      highlight: true,
      detail: 'Par LED Chauvet Intimidator 160W',
      extra: '24 livres nas mesmas datas',
      cost: 'R$ 35/dia (mesmo preço)',
      impact: 'Neutro',
      badge: 'RECOMENDADO',
      tradeoff: 'Foco um pouco mais fechado (12° vs 18°) · cliente aceitou em evento similar',
    },
    {
      id: 'shift-dates',
      label: 'Deslocar datas do projeto',
      detail: 'Mover início pra 24/03 (+1 dia)',
      extra: 'Todos os 20 Par LED ficam livres',
      cost: 'Zero',
      impact: 'Precisa confirmar com cliente',
      tradeoff: 'Montagem fica em dia útil · logística +1 hora',
    },
    {
      id: 'split-supply',
      label: 'Dividir entre 2 modelos',
      detail: '12× Par LED 18x10W + 8× Intimidator 160W',
      extra: 'Usa estoque misto',
      cost: 'R$ 35/dia cada',
      impact: 'Requer ajuste no rider',
      tradeoff: 'Tecnicamente possível · pode ficar visualmente inconsistente',
    },
    {
      id: 'subrental',
      label: 'Sub-locar de parceiro',
      detail: '8 unidades da Luminária Central',
      extra: 'Confirmado disponibilidade por telefone',
      cost: 'R$ 48/dia (+37% custo)',
      impact: 'Reduz margem em R$ 1.560',
      tradeoff: 'Resolve 100% · precisa agendar retirada',
    },
  ];

  return (
    <div style={{ width: 1280, height: 820, position: 'relative', background: 'var(--bg-0)', display: 'flex' }}>
      <Caustic />
      <SideRail active="calendar" />

      <div style={{ flex: 1, padding: '28px 32px', position: 'relative', zIndex: 2, display: 'flex', flexDirection: 'column', gap: 18, overflow: 'auto' }}>
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 16 }}>
          <div style={{ flex: 1 }}>
            <div className="mono" style={{ fontSize: 10, color: '#ff6b6b', letterSpacing: 0.12, textTransform: 'uppercase', marginBottom: 4 }}>⚠ Conflito de disponibilidade · 1 de 2</div>
            <h1 style={{ margin: 0, fontSize: 28, fontWeight: 500, letterSpacing: -0.4, color: 'var(--fg-0)' }}>Par LED 18x10W · faltam 8 unidades</h1>
            <div style={{ fontSize: 13, color: 'var(--fg-2)', marginTop: 6, lineHeight: 1.5 }}>
              <b style={{ color: 'var(--fg-0)' }}>Feira Construção SP</b> (23-27 mar) pede 20 unidades. Nas datas pedidas só <b style={{ color: '#ff6b6b' }}>12 estão livres</b> — 4 ainda no Casamento Santos (retorno 24/03) · 4 em reparo (previsão 28/03).
            </div>
          </div>
          <GhostBtn>Pular conflito</GhostBtn>
        </div>

        {/* Visual conflict bar */}
        <div className="glass" style={{ padding: 18, borderRadius: 16 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            {/* Need */}
            <div style={{ textAlign: 'center', flex: 'none' }}>
              <div className="mono" style={{ fontSize: 9, color: 'var(--fg-2)', letterSpacing: 0.12, textTransform: 'uppercase' }}>Pedido</div>
              <div style={{ fontSize: 34, fontWeight: 500, color: 'var(--fg-0)', lineHeight: 1, fontFamily: 'var(--font-mono)' }}>20</div>
              <div style={{ fontSize: 10, color: 'var(--fg-3)' }}>unidades</div>
            </div>

            {/* Stacked supply viz */}
            <div style={{ flex: 1 }}>
              <div style={{ display: 'flex', gap: 2, height: 28, borderRadius: 8, overflow: 'hidden', border: '1px solid var(--glass-border)' }}>
                {[...Array(12)].map((_, i) => (
                  <div key={i} style={{ flex: 1, background: 'color-mix(in oklch, #6dd18e 50%, var(--bg-1))', borderRight: i < 11 ? '1px solid var(--bg-0)' : 'none' }} />
                ))}
                {[...Array(4)].map((_, i) => (
                  <div key={`p${i}`} style={{ flex: 1, background: 'color-mix(in oklch, #b39cff 50%, var(--bg-1))', borderRight: '1px solid var(--bg-0)' }} />
                ))}
                {[...Array(4)].map((_, i) => (
                  <div key={`r${i}`} style={{ flex: 1, background: 'color-mix(in oklch, #ff6b6b 50%, var(--bg-1))', borderRight: i < 3 ? '1px solid var(--bg-0)' : 'none' }} />
                ))}
              </div>
              <div style={{ display: 'flex', gap: 16, marginTop: 8, fontSize: 11, color: 'var(--fg-2)' }}>
                <span><span style={{ display: 'inline-block', width: 10, height: 10, borderRadius: 2, background: '#6dd18e', verticalAlign: 'middle', marginRight: 5 }} /> 12 livres</span>
                <span><span style={{ display: 'inline-block', width: 10, height: 10, borderRadius: 2, background: '#b39cff', verticalAlign: 'middle', marginRight: 5 }} /> 4 em packing (retorno 24/03)</span>
                <span><span style={{ display: 'inline-block', width: 10, height: 10, borderRadius: 2, background: '#ff6b6b', verticalAlign: 'middle', marginRight: 5 }} /> 4 em reparo (disponível 28/03)</span>
              </div>
            </div>

            {/* Arrow */}
            <div style={{ color: 'var(--fg-3)', fontSize: 24 }}>→</div>

            {/* Missing */}
            <div style={{ textAlign: 'center', flex: 'none', padding: '10px 18px', borderRadius: 12, background: 'rgba(255, 107, 107, 0.1)', border: '1px solid rgba(255, 107, 107, 0.35)' }}>
              <div className="mono" style={{ fontSize: 9, color: '#ff6b6b', letterSpacing: 0.12, textTransform: 'uppercase' }}>Faltam</div>
              <div style={{ fontSize: 34, fontWeight: 500, color: '#ff6b6b', lineHeight: 1, fontFamily: 'var(--font-mono)' }}>8</div>
            </div>
          </div>
        </div>

        {/* Options grid */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
          {options.map(o => (
            <div key={o.id} className="glass" style={{
              padding: 18, borderRadius: 14, cursor: 'pointer', position: 'relative',
              border: o.highlight ? '1.5px solid #6dd18e' : '1px solid var(--glass-border)',
              background: o.highlight ? 'rgba(109, 209, 142, 0.06)' : undefined,
            }}>
              {o.badge && (
                <div style={{ position: 'absolute', top: 14, right: 14, padding: '3px 8px', borderRadius: 6, background: '#6dd18e', color: '#0a1424', fontSize: 9, fontWeight: 600, fontFamily: 'var(--font-mono)', letterSpacing: 0.1 }}>{o.badge}</div>
              )}
              <div style={{ display: 'flex', gap: 12, marginBottom: 10 }}>
                <div style={{ width: 20, height: 20, borderRadius: 10, border: `2px solid ${o.highlight ? '#6dd18e' : 'var(--glass-border-strong)'}`, flexShrink: 0, marginTop: 2, position: 'relative' }}>
                  {o.highlight && <div style={{ position: 'absolute', inset: 3, borderRadius: '50%', background: '#6dd18e' }} />}
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 15, fontWeight: 500, color: 'var(--fg-0)' }}>{o.label}</div>
                  <div style={{ fontSize: 13, color: 'var(--fg-1)', marginTop: 2 }}>{o.detail}</div>
                  <div className="mono" style={{ fontSize: 11, color: o.highlight ? '#6dd18e' : 'var(--accent-cyan)', marginTop: 6 }}>{o.extra}</div>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, padding: '10px 0', borderTop: '1px solid var(--glass-border)' }}>
                <div>
                  <div className="mono" style={{ fontSize: 9, color: 'var(--fg-3)', letterSpacing: 0.1, textTransform: 'uppercase' }}>Custo</div>
                  <div style={{ fontSize: 12, color: 'var(--fg-0)', marginTop: 2 }}>{o.cost}</div>
                </div>
                <div>
                  <div className="mono" style={{ fontSize: 9, color: 'var(--fg-3)', letterSpacing: 0.1, textTransform: 'uppercase' }}>Impacto</div>
                  <div style={{ fontSize: 12, color: 'var(--fg-0)', marginTop: 2 }}>{o.impact}</div>
                </div>
              </div>

              <div style={{ fontSize: 11, color: 'var(--fg-2)', lineHeight: 1.5, paddingTop: 6, borderTop: '1px solid var(--glass-border)' }}>
                <b style={{ color: 'var(--fg-1)' }}>Trade-off:</b> {o.tradeoff}
              </div>
            </div>
          ))}
        </div>

        {/* CTA */}
        <div style={{ display: 'flex', gap: 10, justifyContent: 'space-between', alignItems: 'center', marginTop: 4 }}>
          <div style={{ fontSize: 12, color: 'var(--fg-2)' }}>
            Conflito <b style={{ color: 'var(--fg-0)' }}>1 de 2</b> · próximo: Mesa Yamaha QL5 (Festival Primavera)
          </div>
          <div style={{ display: 'flex', gap: 10 }}>
            <GhostBtn>Salvar pra depois</GhostBtn>
            <PrimaryBtn>Aplicar alternativa · próximo →</PrimaryBtn>
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { ConflictResolver });
