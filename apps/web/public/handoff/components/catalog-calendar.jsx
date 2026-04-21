// catalog-calendar.jsx — Master catalog + availability calendar
// Both web screens. Source of truth: Supabase (inventory sheet).

// ═══════════════════════════════════════════════════════════
// Catalog Master — web
// ═══════════════════════════════════════════════════════════
function CatalogMaster() {
  const categories = [
    { id: 'all', label: 'Todos', count: 1247, active: true },
    { id: 'iluminacao', label: 'Iluminação', count: 312 },
    { id: 'audio', label: 'Áudio', count: 288 },
    { id: 'estrutura', label: 'Estrutura', count: 156 },
    { id: 'cabos', label: 'Cabos & conectores', count: 412 },
    { id: 'video', label: 'Vídeo', count: 44 },
    { id: 'acessorios', label: 'Acessórios', count: 35 },
  ];

  const products = [
    { code: 'MMD-ILU-0042', name: 'Par LED 18x10W RGBWA+UV', cat: 'Iluminação', qty: 24, avail: 16, price: 35, supplier: 'Chauvet Professional', img: 'led', rating: 4.8, uses: 127 },
    { code: 'MMD-ILU-0088', name: 'Moving Head Beam 230W', cat: 'Iluminação', qty: 8, avail: 3, price: 180, supplier: 'Robe Lighting', img: 'beam', rating: 4.9, uses: 89, hot: true },
    { code: 'MMD-AUD-0003', name: 'Mesa Digital Yamaha QL5', cat: 'Áudio', qty: 2, avail: 2, price: 650, supplier: 'Yamaha · Loja Pro', img: 'mixer', rating: 5.0, uses: 42 },
    { code: 'MMD-AUD-0024', name: 'Subwoofer JBL SRX818SP', cat: 'Áudio', qty: 8, avail: 4, price: 220, supplier: 'Harman Brasil', img: 'sub', rating: 4.7, uses: 103 },
    { code: 'MMD-AUD-0088', name: 'Caixa JBL VRX932LAP', cat: 'Áudio', qty: 12, avail: 12, price: 180, supplier: 'Harman Brasil', img: 'line', rating: 4.6, uses: 98 },
    { code: 'MMD-EST-0015', name: 'Box Truss Q30 · 3m', cat: 'Estrutura', qty: 40, avail: 28, price: 48, supplier: 'Alutec Brasil', img: 'truss', rating: 4.8, uses: 215, hot: true },
    { code: 'MMD-EST-0020', name: 'Base tripé Q30 · 5m', cat: 'Estrutura', qty: 16, avail: 16, price: 120, supplier: 'Alutec Brasil', img: 'tripod', rating: 4.7, uses: 88 },
    { code: 'MMD-CAB-L012', name: 'Cabo XLR Canare · 10m', cat: 'Cabos', qty: 200, avail: 160, price: 8, supplier: 'Canare · dist. SP', img: 'xlr', rating: 4.5, uses: 512, batch: true },
  ];

  // tiny product icons
  const Icon = ({ type }) => {
    const base = { stroke: 'currentColor', strokeWidth: 1.3, fill: 'none', strokeLinecap: 'round', strokeLinejoin: 'round' };
    const glyphs = {
      led: <g {...base}><rect x="4" y="8" width="24" height="16" rx="2"/><circle cx="10" cy="16" r="2"/><circle cx="16" cy="16" r="2"/><circle cx="22" cy="16" r="2"/><path d="M4 12h24" opacity="0.4"/></g>,
      beam: <g {...base}><circle cx="16" cy="12" r="4"/><path d="M12 12v8M20 12v8M16 16v8"/><path d="M10 22h12"/></g>,
      mixer: <g {...base}><rect x="3" y="6" width="26" height="20" rx="2"/><path d="M7 10v12M11 10v12M15 10v12M19 10v12M23 10v12"/></g>,
      sub: <g {...base}><rect x="4" y="4" width="24" height="24" rx="2"/><circle cx="16" cy="16" r="6"/><circle cx="16" cy="16" r="2"/></g>,
      line: <g {...base}><path d="M6 6l20 0M6 12l20 0M6 18l20 0M6 24l20 0"/><circle cx="16" cy="6" r="1"/><circle cx="16" cy="12" r="1"/><circle cx="16" cy="18" r="1"/><circle cx="16" cy="24" r="1"/></g>,
      truss: <g {...base}><path d="M2 10L30 10M2 22L30 22M2 10L30 22M30 10L2 22"/></g>,
      tripod: <g {...base}><path d="M16 4v14M16 18L6 28M16 18L26 28M10 24h12"/></g>,
      xlr: <g {...base}><circle cx="12" cy="16" r="6"/><circle cx="12" cy="14" r="0.8" fill="currentColor"/><circle cx="10" cy="18" r="0.8" fill="currentColor"/><circle cx="14" cy="18" r="0.8" fill="currentColor"/><path d="M18 16h12"/></g>,
    };
    return <svg width="32" height="32" viewBox="0 0 32 32">{glyphs[type] || glyphs.led}</svg>;
  };

  const catColors = {
    'Iluminação': '#ffb75c', 'Áudio': '#7cc4ff', 'Estrutura': '#b39cff', 'Cabos': '#6dd18e', 'Vídeo': '#ff6b6b',
  };

  return (
    <div style={{ width: 1280, height: 820, position: 'relative', background: 'var(--bg-0)', display: 'flex' }}>
      <Caustic />
      <SideRail active="catalog" />

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', position: 'relative', zIndex: 2 }}>
        {/* Header */}
        <div style={{ padding: '24px 32px 16px', display: 'flex', alignItems: 'flex-end', gap: 16 }}>
          <div style={{ flex: 1 }}>
            <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', letterSpacing: 0.08, textTransform: 'uppercase', marginBottom: 4 }}>Catálogo · fonte Supabase</div>
            <h1 style={{ margin: 0, fontSize: 28, fontWeight: 500, letterSpacing: -0.4, color: 'var(--fg-0)' }}>Produtos mestres</h1>
            <div style={{ display: 'flex', gap: 16, marginTop: 6, fontSize: 12, color: 'var(--fg-2)' }}>
              <span><b style={{ color: 'var(--fg-1)' }}>1.247</b> produtos</span>
              <span><b style={{ color: 'var(--fg-1)' }}>3.892</b> unidades (serials)</span>
              <span>última sync <b style={{ color: '#6dd18e' }}>agora</b></span>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <GhostBtn>{Icons.qr} Imprimir QR</GhostBtn>
            <GhostBtn>Importar CSV</GhostBtn>
            <PrimaryBtn>{Icons.plus} Novo produto</PrimaryBtn>
          </div>
        </div>

        {/* Search + filters bar */}
        <div style={{ padding: '0 32px', display: 'flex', gap: 10, alignItems: 'center' }}>
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 10, padding: '10px 14px', borderRadius: 12,
            background: 'var(--glass-bg)', border: '1px solid var(--glass-border)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)' }}>
            <span style={{ color: 'var(--fg-3)' }}>{Icons.search}</span>
            <input placeholder="Buscar por nome, código, fornecedor..." style={{ flex: 1, background: 'transparent', border: 'none', outline: 'none', color: 'var(--fg-0)', fontSize: 13, fontFamily: 'inherit' }} defaultValue="" />
            <span style={{ fontFamily: 'var(--font-mono)', fontSize: 10, color: 'var(--fg-3)', padding: '2px 6px', borderRadius: 4, background: 'var(--glass-bg)' }}>⌘K</span>
          </div>
          <div className="seg" style={{ flex: 'none' }}>
            <button className="active">Grade</button>
            <button>Tabela</button>
          </div>
        </div>

        {/* Category chips */}
        <div style={{ padding: '14px 32px 0', display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {categories.map(c => (
            <div key={c.id} style={{
              padding: '6px 12px', borderRadius: 999, fontSize: 12,
              background: c.active ? 'var(--glass-bg-strong)' : 'var(--glass-bg)',
              border: `1px solid ${c.active ? 'var(--glass-border-strong)' : 'var(--glass-border)'}`,
              color: c.active ? 'var(--fg-0)' : 'var(--fg-2)', cursor: 'pointer',
              display: 'inline-flex', alignItems: 'center', gap: 8,
            }}>
              {c.label}
              <span style={{ fontSize: 10, fontFamily: 'var(--font-mono)', color: 'var(--fg-3)' }}>{c.count}</span>
            </div>
          ))}
        </div>

        {/* Product grid */}
        <div style={{ flex: 1, overflow: 'auto', padding: '18px 32px 28px' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 14 }}>
            {products.map((p, i) => {
              const catColor = catColors[p.cat] || '#7cc4ff';
              const availPct = p.qty === 0 ? 0 : p.avail / p.qty;
              return (
                <div key={p.code} className="glass" style={{ padding: 16, borderRadius: 16, position: 'relative', cursor: 'pointer', display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {p.hot && (
                    <div style={{ position: 'absolute', top: 12, right: 12, padding: '2px 8px', borderRadius: 6, background: 'rgba(255, 183, 92, 0.15)', border: '1px solid #ffb75c', fontSize: 9, color: '#ffb75c', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase' }}>Alta demanda</div>
                  )}
                  <div style={{
                    height: 90, borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'center',
                    background: `radial-gradient(circle at 50% 40%, color-mix(in oklch, ${catColor} 22%, transparent) 0%, color-mix(in oklch, ${catColor} 5%, transparent) 60%)`,
                    border: '1px solid var(--glass-border)', color: catColor,
                  }}>
                    <div style={{ transform: 'scale(1.6)' }}><Icon type={p.img} /></div>
                  </div>
                  <div>
                    <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--fg-0)', lineHeight: 1.3, minHeight: 34 }}>{p.name}</div>
                    <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', marginTop: 3, display: 'flex', justifyContent: 'space-between' }}>
                      <span>{p.code}</span>
                      <span style={{ color: catColor }}>{p.cat}</span>
                    </div>
                  </div>
                  {/* Availability bar */}
                  <div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 10, fontFamily: 'var(--font-mono)', color: 'var(--fg-2)', marginBottom: 4 }}>
                      <span>Disponível</span>
                      <span style={{ color: availPct > 0.5 ? '#6dd18e' : availPct > 0.2 ? '#ffb75c' : '#ff6b6b' }}>{p.avail}/{p.qty}{p.batch ? ' un.' : ''}</span>
                    </div>
                    <div style={{ height: 3, borderRadius: 2, background: 'var(--glass-border)', overflow: 'hidden' }}>
                      <div style={{ width: `${availPct*100}%`, height: '100%', background: availPct > 0.5 ? '#6dd18e' : availPct > 0.2 ? '#ffb75c' : '#ff6b6b' }} />
                    </div>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', paddingTop: 6, borderTop: '1px solid var(--glass-border)' }}>
                    <div>
                      <div style={{ fontSize: 16, fontWeight: 500, color: 'var(--fg-0)', fontFamily: 'var(--font-mono)' }}>R$ {p.price}</div>
                      <div style={{ fontSize: 9, color: 'var(--fg-3)', fontFamily: 'var(--font-mono)', letterSpacing: 0.05, textTransform: 'uppercase' }}>por dia</div>
                    </div>
                    <div style={{ textAlign: 'right', fontSize: 10, color: 'var(--fg-3)' }}>
                      <div>{p.uses}× locado</div>
                      <div style={{ color: '#ffb75c', marginTop: 2 }}>★ {p.rating}</div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// Availability Calendar — web
// ═══════════════════════════════════════════════════════════
function AvailCalendar() {
  // 21 days starting 15/03
  const days = [...Array(21)].map((_, i) => {
    const d = 15 + i;
    const date = d > 31 ? d - 31 : d;
    const month = d > 31 ? 'abr' : 'mar';
    const dow = (i + 5) % 7; // arbitrary starting weekday
    return { d: date, m: month, dow, weekend: dow === 0 || dow === 6, today: i === 3 };
  });

  // Bookings per row (item) — each is a horizontal bar
  const rows = [
    { code: 'MMD-ILU-0042', name: 'Par LED 18x10W', qty: 24, cat: '#ffb75c', bookings: [
      { start: 0, end: 3, qty: 12, project: 'Réveillon Copacabana (resíduo)', phase: 'pack' },
      { start: 3, end: 6, qty: 16, project: 'Casamento Santos', phase: 'confirmed' },
      { start: 8, end: 12, qty: 20, project: 'Feira Construção SP', phase: 'confirmed', conflict: true },
      { start: 14, end: 17, qty: 10, project: 'Show Banda Local', phase: 'tentative' },
    ]},
    { code: 'MMD-ILU-0088', name: 'Moving Head Beam 230W', qty: 8, cat: '#ffb75c', bookings: [
      { start: 3, end: 6, qty: 5, project: 'Casamento Santos', phase: 'confirmed' },
      { start: 7, end: 10, qty: 8, project: 'Congresso Medicina', phase: 'confirmed' },
      { start: 11, end: 13, qty: 4, project: 'Show TV Globo', phase: 'tentative' },
      { start: 15, end: 18, qty: 8, project: 'Festival Primavera', phase: 'confirmed' },
    ]},
    { code: 'MMD-AUD-0003', name: 'Mesa Digital Yamaha QL5', qty: 2, cat: '#7cc4ff', bookings: [
      { start: 3, end: 6, qty: 1, project: 'Casamento Santos', phase: 'confirmed' },
      { start: 7, end: 10, qty: 1, project: 'Congresso Medicina', phase: 'confirmed' },
      { start: 11, end: 13, qty: 2, project: 'Show TV Globo', phase: 'confirmed' },
      { start: 15, end: 18, qty: 2, project: 'Festival Primavera', phase: 'confirmed', conflict: true },
    ]},
    { code: 'MMD-AUD-0024', name: 'Subwoofer JBL SRX818SP', qty: 8, cat: '#7cc4ff', bookings: [
      { start: 3, end: 6, qty: 4, project: 'Casamento Santos', phase: 'confirmed' },
      { start: 15, end: 18, qty: 6, project: 'Festival Primavera', phase: 'confirmed' },
    ]},
    { code: 'MMD-EST-0015', name: 'Box Truss Q30 · 3m', qty: 40, cat: '#b39cff', bookings: [
      { start: 2, end: 6, qty: 12, project: 'Casamento Santos', phase: 'confirmed' },
      { start: 7, end: 10, qty: 24, project: 'Congresso Medicina', phase: 'confirmed' },
      { start: 11, end: 13, qty: 18, project: 'Show TV Globo', phase: 'confirmed' },
      { start: 15, end: 19, qty: 32, project: 'Festival Primavera', phase: 'confirmed' },
    ]},
    { code: 'MMD-CAB-L012', name: 'Cabo XLR Canare · 10m', qty: 200, cat: '#6dd18e', bookings: [
      { start: 3, end: 6, qty: 40, project: 'Casamento Santos', phase: 'confirmed' },
      { start: 7, end: 10, qty: 80, project: 'Congresso Medicina', phase: 'confirmed' },
      { start: 15, end: 19, qty: 120, project: 'Festival Primavera', phase: 'confirmed' },
    ]},
  ];

  const colW = 42, rowH = 56, leftW = 260;
  const phaseStyle = (b) => {
    if (b.conflict) return { bg: 'rgba(255, 107, 107, 0.2)', border: '#ff6b6b', text: '#ff6b6b' };
    if (b.phase === 'tentative') return { bg: 'rgba(255, 255, 255, 0.06)', border: 'rgba(255, 255, 255, 0.25)', text: 'var(--fg-1)', dashed: true };
    if (b.phase === 'pack') return { bg: 'rgba(179, 156, 255, 0.18)', border: '#b39cff', text: '#b39cff' };
    return { bg: 'color-mix(in oklch, var(--accent-cyan) 15%, transparent)', border: 'var(--accent-cyan)', text: 'var(--accent-cyan)' };
  };

  return (
    <div style={{ width: 1280, height: 820, position: 'relative', background: 'var(--bg-0)', display: 'flex' }}>
      <Caustic />
      <SideRail active="calendar" />

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', position: 'relative', zIndex: 2 }}>
        {/* Header */}
        <div style={{ padding: '24px 32px 16px', display: 'flex', alignItems: 'flex-end', gap: 16 }}>
          <div style={{ flex: 1 }}>
            <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', letterSpacing: 0.08, textTransform: 'uppercase', marginBottom: 4 }}>Disponibilidade · timeline</div>
            <h1 style={{ margin: 0, fontSize: 28, fontWeight: 500, letterSpacing: -0.4, color: 'var(--fg-0)' }}>Março · Abril 2025</h1>
            <div style={{ display: 'flex', gap: 16, marginTop: 6, fontSize: 12, color: 'var(--fg-2)' }}>
              <span><b style={{ color: '#ff6b6b' }}>2 conflitos</b> detectados</span>
              <span><b style={{ color: 'var(--fg-1)' }}>7 projetos</b> ativos</span>
              <span><b style={{ color: 'var(--fg-1)' }}>21 dias</b> visíveis</span>
            </div>
          </div>
          <div className="seg">
            <button>Dia</button>
            <button className="active">Semana</button>
            <button>Mês</button>
            <button>Trimestre</button>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <GhostBtn small>‹ Anterior</GhostBtn>
            <GhostBtn small>Hoje</GhostBtn>
            <GhostBtn small>Próximo ›</GhostBtn>
          </div>
        </div>

        {/* Legend */}
        <div style={{ padding: '0 32px', display: 'flex', gap: 18, alignItems: 'center', fontSize: 11, color: 'var(--fg-2)' }}>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}><span style={{ width: 14, height: 10, borderRadius: 3, background: 'color-mix(in oklch, var(--accent-cyan) 15%, transparent)', border: '1px solid var(--accent-cyan)' }} /> Confirmado</span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}><span style={{ width: 14, height: 10, borderRadius: 3, background: 'rgba(255,255,255,0.06)', border: '1px dashed rgba(255, 255, 255, 0.3)' }} /> Tentativo</span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}><span style={{ width: 14, height: 10, borderRadius: 3, background: 'rgba(179, 156, 255, 0.2)', border: '1px solid #b39cff' }} /> Em packing</span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}><span style={{ width: 14, height: 10, borderRadius: 3, background: 'rgba(255, 107, 107, 0.2)', border: '1px solid #ff6b6b' }} /> Conflito</span>
          <div style={{ flex: 1 }} />
          <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.1, textTransform: 'uppercase' }}>Clique numa barra pra ver detalhes</div>
        </div>

        {/* Timeline grid */}
        <div style={{ flex: 1, margin: '16px 32px 24px', borderRadius: 16, overflow: 'hidden',
          background: 'var(--glass-bg)', border: '1px solid var(--glass-border)',
          backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)' }}>
          <div style={{ display: 'flex', height: '100%', overflow: 'auto' }}>
            {/* Left rail: item names */}
            <div style={{ width: leftW, flex: 'none', borderRight: '1px solid var(--glass-border)', background: 'var(--glass-bg-strong)' }}>
              <div style={{ height: 40, display: 'flex', alignItems: 'center', padding: '0 14px', borderBottom: '1px solid var(--glass-border)' }}>
                <span className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', letterSpacing: 0.1, textTransform: 'uppercase' }}>Item · estoque</span>
              </div>
              {rows.map((r, i) => (
                <div key={r.code} style={{ height: rowH, display: 'flex', alignItems: 'center', gap: 10, padding: '0 14px', borderBottom: i < rows.length-1 ? '1px solid var(--glass-border)' : 'none' }}>
                  <div style={{ width: 8, height: 8, borderRadius: 2, background: r.cat }} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 12, color: 'var(--fg-0)', fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.name}</div>
                    <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', marginTop: 2 }}>{r.code} · {r.qty} un.</div>
                  </div>
                </div>
              ))}
            </div>

            {/* Timeline body */}
            <div style={{ position: 'relative', minWidth: colW * days.length }}>
              {/* Day headers */}
              <div style={{ height: 40, display: 'flex', borderBottom: '1px solid var(--glass-border)', background: 'var(--glass-bg-strong)' }}>
                {days.map((day, i) => (
                  <div key={i} style={{
                    width: colW, flex: 'none', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
                    borderRight: i < days.length-1 ? '1px solid var(--glass-border)' : 'none',
                    background: day.today ? 'color-mix(in oklch, var(--accent-cyan) 10%, transparent)' : day.weekend ? 'rgba(0,0,0,0.15)' : 'transparent',
                  }}>
                    <span style={{ fontSize: 9, color: day.today ? 'var(--accent-cyan)' : 'var(--fg-3)', fontFamily: 'var(--font-mono)', letterSpacing: 0.05, textTransform: 'uppercase' }}>
                      {['dom','seg','ter','qua','qui','sex','sáb'][day.dow]}
                    </span>
                    <span style={{ fontSize: 13, fontWeight: day.today ? 600 : 400, color: day.today ? 'var(--accent-cyan)' : 'var(--fg-1)', fontFamily: 'var(--font-mono)' }}>{day.d}</span>
                  </div>
                ))}
              </div>

              {/* Rows */}
              {rows.map((r, ri) => (
                <div key={r.code} style={{ height: rowH, position: 'relative', borderBottom: ri < rows.length-1 ? '1px solid var(--glass-border)' : 'none' }}>
                  {/* Grid lines */}
                  {days.map((day, i) => (
                    <div key={i} style={{
                      position: 'absolute', left: i*colW, top: 0, bottom: 0, width: colW,
                      borderRight: i < days.length-1 ? '1px solid var(--glass-border)' : 'none',
                      background: day.today ? 'color-mix(in oklch, var(--accent-cyan) 5%, transparent)' : day.weekend ? 'rgba(0,0,0,0.1)' : 'transparent',
                    }} />
                  ))}
                  {/* Bookings */}
                  {r.bookings.map((b, bi) => {
                    const s = phaseStyle(b);
                    const left = b.start * colW + 3;
                    const width = (b.end - b.start) * colW - 6;
                    return (
                      <div key={bi} style={{
                        position: 'absolute', top: 8, left, width, height: rowH - 16,
                        borderRadius: 8,
                        background: s.bg,
                        border: `1px ${s.dashed ? 'dashed' : 'solid'} ${s.border}`,
                        padding: '4px 8px',
                        display: 'flex', flexDirection: 'column', justifyContent: 'center',
                        overflow: 'hidden', cursor: 'pointer',
                      }}>
                        <div style={{ fontSize: 10, color: s.text, fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', display: 'flex', alignItems: 'center', gap: 4 }}>
                          {b.conflict && <span>⚠</span>}
                          {b.project}
                        </div>
                        <div style={{ fontSize: 9, fontFamily: 'var(--font-mono)', color: s.text, opacity: 0.8, marginTop: 1 }}>
                          {b.qty}/{r.qty} un.
                        </div>
                      </div>
                    );
                  })}
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Conflict summary — bottom */}
        <div style={{ position: 'absolute', bottom: 24, right: 48, width: 340, padding: 14, borderRadius: 14,
          background: 'rgba(255, 107, 107, 0.1)', border: '1px solid rgba(255, 107, 107, 0.35)',
          backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
          boxShadow: '0 20px 60px rgba(0,0,0,0.3)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
            <StatusDot color="#ff6b6b" size={8} />
            <span className="mono" style={{ fontSize: 10, color: '#ff6b6b', letterSpacing: 0.12, textTransform: 'uppercase' }}>2 conflitos de disponibilidade</span>
          </div>
          <div style={{ fontSize: 12, color: 'var(--fg-0)', lineHeight: 1.5 }}>
            <b>Par LED 18x10W</b> — Feira Construção pede 20, só 12 livres (4 ainda no Casamento).
            <br/>
            <b>Mesa Yamaha QL5</b> — Festival Primavera pede 2, só 1 disponível.
          </div>
          <div style={{ display: 'flex', gap: 6, marginTop: 10 }}>
            <GhostBtn small>Ver alternativas</GhostBtn>
            <PrimaryBtn small>Resolver conflitos</PrimaryBtn>
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { CatalogMaster, AvailCalendar });
