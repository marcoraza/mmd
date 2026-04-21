// screen-checkout-combined.jsx — Hybrid grid + list checkout

function CheckoutCombined() {
  const [filter, setFilter] = React.useState('all'); // 'all' | 'missing' | 'ok'
  const [focused, setFocused] = React.useState(null); // cell index

  // 108 cells visible (6 rows × 18 cols) · representa 214 totais
  const missingSet = new Set([3,7,18,22,31,45,56,72,89,101,4,41,68,92,55,77,99,48,65,82,85,38,27,14,104,73,16]);
  const cells = Array.from({length: 108}, (_, i) => ({
    i, status: missingSet.has(i) ? 'missing' : 'ok',
    name: ['Par LED 18x10W','Moving Head Beam','Cabo XLR 10m','Caixa JBL','Box Truss Q30','Subwoofer','Mesa Yamaha','Cabo Powercon'][i%8],
    code: `MMD-${['ILU','AUD','CAB','EST'][i%4]}-${String(42+i).padStart(4,'0')}-${String(i).padStart(3,'0')}`,
  }));

  // Aggregated rows for the list
  const rows = [
    { n: 'Box Truss Q30 3m', c: 'MMD-EST-0009', status: 'missing', qty: 12, alloc: 0, cat: 'Estrutura' },
    { n: 'Moving Head Beam 230W', c: 'MMD-ILU-0088', status: 'partial', qty: 8, alloc: 6, cat: 'Iluminação' },
    { n: 'Cabo XLR 10m (lote)', c: 'MMD-CAB-L012', status: 'partial', qty: 40, alloc: 32, cat: 'Cabo' },
    { n: 'Par LED 18x10W', c: 'MMD-ILU-0042', status: 'ok', qty: 16, alloc: 16, cat: 'Iluminação' },
    { n: 'Mesa Yamaha QL5', c: 'MMD-AUD-0003', status: 'ok', qty: 1, alloc: 1, cat: 'Áudio' },
    { n: 'Subwoofer JBL SRX818', c: 'MMD-AUD-0024', status: 'ok', qty: 4, alloc: 4, cat: 'Áudio' },
    { n: 'Cabo Powercon 5m', c: 'MMD-CAB-L004', status: 'ok', qty: 30, alloc: 30, cat: 'Cabo' },
    { n: 'Caixa JBL VRX932', c: 'MMD-AUD-0011', status: 'ok', qty: 8, alloc: 8, cat: 'Áudio' },
  ];

  const visibleRows = rows.filter(r => {
    if (filter === 'missing') return r.status !== 'ok';
    if (filter === 'ok') return r.status === 'ok';
    return true;
  });

  return (
    <IOSDevice dark width={402} height={874}>
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, oklch(0.14 0.04 250), oklch(0.08 0.02 250))' }} />

      {/* nav */}
      <div style={{ position: 'absolute', top: 54, left: 16, right: 16, display: 'flex', alignItems: 'center', gap: 10, zIndex: 6 }}>
        <IOSGlassPill dark><div style={{ padding: '0 12px', fontSize: 13, color: '#fff' }}>Voltar</div></IOSGlassPill>
        <div style={{ flex: 1, textAlign: 'center' }}>
          <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase' }}>Saída · packing</div>
          <div style={{ fontSize: 14, color: '#fff', fontWeight: 600 }}>Casamento Santos</div>
        </div>
        <IOSGlassPill dark><div style={{ padding: '0 12px', fontSize: 13, color: '#fff' }}>{Icons.qr}</div></IOSGlassPill>
      </div>

      {/* Readiness + big number */}
      <div style={{ position: 'absolute', top: 115, left: 16, right: 16, display: 'flex', alignItems: 'center', gap: 16 }}>
        <Ring value={87} size={72} stroke={6} />
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 28, fontWeight: 500, color: '#fff', letterSpacing: -0.6, lineHeight: 1 }}>
            187<span style={{ color: 'rgba(255,255,255,0.4)', fontSize: 16 }}>/214</span>
          </div>
          <div style={{ fontSize: 12, color: '#ffb75c', marginTop: 4, fontWeight: 500 }}>27 faltando</div>
          <div style={{ marginTop: 6, height: 3, borderRadius: 2, background: 'rgba(255,255,255,0.1)', overflow: 'hidden' }}>
            <div style={{ width: '87%', height: '100%', background: 'linear-gradient(90deg, #6dd18e, #7cc4ff)' }} />
          </div>
        </div>
      </div>

      {/* Grid glance (tap cell = focus that serial in list) */}
      <div style={{ position: 'absolute', top: 220, left: 16, right: 16, padding: 12, borderRadius: 18,
        background: 'rgba(255,255,255,0.04)', backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
        border: '1px solid rgba(255,255,255,0.1)' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
          <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.6)', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase' }}>214 unidades · toque p/ localizar</div>

          <div style={{ display: 'flex', gap: 10, fontSize: 9, color: 'rgba(255,255,255,0.6)' }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}><span style={{ width: 7, height: 7, borderRadius: 2, background: '#6dd18e' }}/>187</span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}><span style={{ width: 7, height: 7, borderRadius: 2, background: '#ff6b6b' }}/>27</span>
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(18, 14px)', gridAutoRows: '14px', gap: 3, justifyContent: 'center' }}>
          {cells.map((c) => {
            const isFocus = focused === c.i;
            return (
              <div key={c.i}
                onClick={() => setFocused(c.i === focused ? null : c.i)}
                style={{
                  width: 14, height: 14, borderRadius: 3,
                  background: c.status === 'ok' ? '#6dd18e' : 'rgba(255, 107, 107, 0.85)',
                  boxShadow: isFocus ? '0 0 0 2px #fff' : (c.status === 'missing' ? '0 0 5px rgba(255, 107, 107, 0.7)' : 'none'),
                  opacity: c.status === 'ok' ? 0.75 : 1,
                  cursor: 'pointer', transition: 'transform 0.15s',
                  transform: isFocus ? 'scale(1.5)' : 'scale(1)',
                  zIndex: isFocus ? 2 : 1,
                  position: 'relative',
                }} />
            );
          })}
        </div>
      </div>

      {/* Filter chips — synced */}
      <div style={{ position: 'absolute', top: 400, left: 16, right: 16, display: 'flex', gap: 6 }}>
        {[
          { id: 'missing', l: 'Faltando', c: '#ffb75c', n: 27 },
          { id: 'ok', l: 'Prontos', c: '#6dd18e', n: 187 },
          { id: 'all', l: 'Tudo', c: 'rgba(255,255,255,0.5)', n: 214 },
        ].map(f => (
          <div key={f.id} onClick={() => setFilter(f.id)} style={{
            padding: '6px 12px', borderRadius: 999, fontSize: 11, fontWeight: 500,
            background: filter === f.id ? `color-mix(in oklch, ${f.c} 25%, transparent)` : 'rgba(255,255,255,0.05)',
            border: filter === f.id ? `1px solid ${f.c}` : '1px solid rgba(255,255,255,0.1)',
            color: filter === f.id ? f.c : 'rgba(255,255,255,0.7)',
            cursor: 'pointer',
            display: 'inline-flex', alignItems: 'center', gap: 6,
          }}>
            <StatusDot color={f.c} size={5} glow={false} />
            {f.l} <span style={{ fontFamily: 'var(--font-mono)', opacity: 0.7 }}>{f.n}</span>
          </div>
        ))}
      </div>

      {/* List — detail/action */}
      <div style={{ position: 'absolute', top: 442, left: 16, right: 16, bottom: 120, borderRadius: 22, overflow: 'hidden',
        background: 'rgba(255,255,255,0.04)', backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
        border: '1px solid rgba(255,255,255,0.1)' }}>
        <div style={{ padding: '10px 14px', borderBottom: '1px solid rgba(255,255,255,0.08)', display: 'flex', alignItems: 'center' }}>
          <span style={{ fontSize: 12, color: '#fff', fontWeight: 500 }}>Por item agregado</span>
          <div style={{ flex: 1 }} />
          <span style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)' }}>{visibleRows.length} linhas</span>
        </div>
        <div style={{ overflow: 'auto', maxHeight: '100%' }}>
          {visibleRows.map((r, i) => {
            const sMap = {
              missing: { c: '#ff6b6b', label: `0/${r.qty}`, icon: Icons.x },
              partial: { c: '#ffb75c', label: `${r.alloc}/${r.qty}`, icon: Icons.warn },
              ok: { c: '#6dd18e', label: `${r.qty}/${r.qty}`, icon: Icons.check },
            };
            const s = sMap[r.status];
            return (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 14px', borderBottom: '0.5px solid rgba(255,255,255,0.06)' }}>
                <div style={{ width: 28, height: 28, borderRadius: 8, background: `color-mix(in oklch, ${s.c} 22%, transparent)`, border: `1px solid ${s.c}`, color: s.c, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{s.icon}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 12, color: '#fff', fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.n}</div>
                  <div style={{ fontSize: 9, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)' }}>{r.c}</div>
                </div>
                <div style={{ fontSize: 12, color: s.c, fontFamily: 'var(--font-mono)', fontWeight: 600 }}>{s.label}</div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Actions */}
      <div style={{ position: 'absolute', bottom: 50, left: 16, right: 16, display: 'flex', gap: 8, zIndex: 6 }}>
        <div style={{
          flex: 1, padding: '13px', borderRadius: 18, textAlign: 'center',
          background: 'rgba(255,255,255,0.08)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
          border: '1px solid rgba(255,255,255,0.15)', color: '#fff', fontWeight: 500, fontSize: 13,
        }}>Continuar lendo</div>
        <div style={{
          flex: 1.1, padding: '13px', borderRadius: 18, textAlign: 'center',
          background: 'linear-gradient(180deg, rgba(124, 196, 255, 0.95), rgba(124, 196, 255, 0.75))',
          boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.3), 0 8px 20px rgba(124, 196, 255, 0.3)',
          color: '#0a1424', fontWeight: 600, fontSize: 13,
        }}>Confirmar saída</div>
      </div>
    </IOSDevice>
  );
}

// ProjectsSwitcher — all 3 views w/ segmented control
function ProjectsSwitcher() {
  const [view, setView] = React.useState('kanban');
  const Views = { kanban: ProjectsV3, timeline: ProjectsV2, split: ProjectsV1 };
  const Cmp = Views[view];

  return (
    <div style={{ position: 'relative', width: DASH_W, height: DASH_H }}>
      <Cmp />
      {/* Segmented overlay */}
      <div style={{
        position: 'absolute', top: 40, right: 40, zIndex: 50,
        padding: 4, borderRadius: 12,
        background: 'rgba(20,20,30,0.7)', backdropFilter: 'blur(30px) saturate(180%)', WebkitBackdropFilter: 'blur(30px) saturate(180%)',
        border: '1px solid rgba(255,255,255,0.15)', display: 'flex', gap: 2,
      }}>
        {[
          { id: 'kanban', l: 'Kanban' },
          { id: 'timeline', l: 'Timeline' },
          { id: 'split', l: 'Split' },
        ].map(v => (
          <div key={v.id} onClick={() => setView(v.id)} style={{
            padding: '6px 12px', borderRadius: 8, fontSize: 12, cursor: 'pointer',
            fontWeight: 500,
            background: view === v.id ? 'rgba(255,255,255,0.15)' : 'transparent',
            color: view === v.id ? '#fff' : 'rgba(255,255,255,0.6)',
            border: view === v.id ? '1px solid rgba(255,255,255,0.2)' : '1px solid transparent',
          }}>{v.l}</div>
        ))}
      </div>
    </div>
  );
}

Object.assign(window, { CheckoutCombined, ProjectsSwitcher });
