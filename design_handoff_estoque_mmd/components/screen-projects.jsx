// screen-projects.jsx — Web Projects & Packing List, 3 variations

// ─────────────────────────────────────────────────────────
// V1 — Split view: project list + packing builder
// ─────────────────────────────────────────────────────────
function ProjectsV1() {
  return (
    <div style={{ width: DASH_W, height: DASH_H, position: 'relative', background: 'var(--bg-0)' }}>
      <Caustic />
      <SideRail active="projects" />

      <div style={{ position: 'absolute', left: 80, right: 0, top: 0, bottom: 0, padding: '28px 32px', overflow: 'hidden' }}>
        <TopBar />

        <div style={{ display: 'grid', gridTemplateColumns: '320px 1fr', gap: 18, marginTop: 24, height: 'calc(100% - 80px)' }}>
          {/* Project list */}
          <GlassCard style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 10, overflow: 'hidden' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '4px 2px' }}>
              <div style={{ fontSize: 14, fontWeight: 500 }}>Projetos</div>
              <div style={{ width: 28, height: 28, borderRadius: 8, background: 'var(--glass-bg-strong)', border: '1px solid var(--glass-border-strong)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--fg-1)' }}>{Icons.plus}</div>
            </div>
            <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.1, textTransform: 'uppercase', marginTop: 4 }}>Ativos · 4</div>
            {[
              { name: 'Casamento Santos & Oliveira', d: '23.abr', items: 214, r: 87, active: true },
              { name: 'Feira Tech SP', d: '28.abr', items: 340, r: 62 },
              { name: 'Show Banda Neon', d: '02.mai', items: 128, r: 100 },
              { name: 'Corporativo ABC', d: '05.mai', items: 89, r: 45 },
            ].map((p, i) => (
              <div key={i} style={{
                padding: 12, borderRadius: 14, cursor: 'pointer',
                background: p.active ? 'var(--glass-bg-strong)' : 'transparent',
                border: p.active ? '1px solid var(--accent-cyan-soft)' : '1px solid transparent',
                display: 'flex', alignItems: 'center', gap: 12,
              }}>
                <Ring value={p.r} size={40} stroke={4} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--fg-0)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{p.name}</div>
                  <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', marginTop: 2 }}>{p.d} · {p.items} itens</div>
                </div>
              </div>
            ))}
            <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.1, textTransform: 'uppercase', marginTop: 12 }}>Concluídos · 2</div>
            {[
              { name: 'Festival Outono', d: '15.abr' },
              { name: 'Evento Rotary', d: '10.abr' },
            ].map((p, i) => (
              <div key={i} style={{ padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 10, opacity: 0.55 }}>
                <StatusDot color="var(--fg-3)" size={6} glow={false} />
                <div style={{ flex: 1, fontSize: 12, color: 'var(--fg-1)' }}>{p.name}</div>
                <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>{p.d}</div>
              </div>
            ))}
          </GlassCard>

          {/* Packing builder */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14, minHeight: 0 }}>
            <GlassCard strong style={{ padding: 20 }}>
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: 20 }}>
                <div style={{ flex: 1 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 4 }}>
                    <StatusDot color="var(--accent-cyan)" size={8} />
                    <span className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', letterSpacing: 0.1, textTransform: 'uppercase' }}>EM MONTAGEM · 2 dias 14h</span>
                  </div>
                  <div style={{ fontSize: 24, fontWeight: 500, color: 'var(--fg-0)', letterSpacing: -0.5 }}>Casamento Santos & Oliveira</div>
                  <div style={{ fontSize: 13, color: 'var(--fg-2)', marginTop: 6 }}>23.abr · 18h · Jardim Botânico · SP</div>
                </div>
                <Ring value={87} size={90} stroke={6} label="readiness" />
                <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                  <PrimaryBtn small>Gerar QR codes</PrimaryBtn>
                  <GhostBtn small>Exportar PDF</GhostBtn>
                </div>
              </div>
            </GlassCard>

            {/* Packing list */}
            <GlassCard style={{ padding: 0, flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
              {/* Header */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 16, padding: '16px 20px', borderBottom: '1px solid var(--glass-border)' }}>
                <div style={{ fontSize: 14, fontWeight: 500 }}>Packing list</div>
                <div className="mono" style={{ fontSize: 11, color: 'var(--fg-2)' }}>214 itens · 89 categorias</div>
                <div style={{ flex: 1 }} />
                <div className="glass" style={{ height: 30, borderRadius: 999, padding: '0 12px', display: 'flex', alignItems: 'center', gap: 8, color: 'var(--fg-2)', fontSize: 12 }}>
                  {Icons.search}<span>Adicionar item…</span>
                </div>
                <GhostBtn small>Filtros</GhostBtn>
              </div>

              {/* Table */}
              <div style={{ flex: 1, overflow: 'hidden', padding: '6px 12px' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
                  <thead>
                    <tr style={{ color: 'var(--fg-3)' }}>
                      {['ITEM', 'CÓDIGO', 'CATEGORIA', 'QTD', 'ALOCADO', 'STATUS', ''].map((h, i) => (
                        <th key={i} className="mono" style={{ fontSize: 10, fontWeight: 400, letterSpacing: 0.08, textAlign: 'left', padding: '10px 12px' }}>{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {[
                      { n: 'Par LED 18x10W RGBW', c: 'MMD-ILU-0042', cat: 'Iluminação', qty: 16, alloc: 16, s: 'ok' },
                      { n: 'Moving Head Beam 230W', c: 'MMD-ILU-0088', cat: 'Iluminação', qty: 8, alloc: 6, s: 'partial' },
                      { n: 'Caixa Line Array JBL VRX932', c: 'MMD-AUD-0011', cat: 'Áudio', qty: 8, alloc: 8, s: 'ok' },
                      { n: 'Subwoofer JBL SRX818SP', c: 'MMD-AUD-0024', cat: 'Áudio', qty: 4, alloc: 4, s: 'ok' },
                      { n: 'Mesa Yamaha QL5', c: 'MMD-AUD-0003', cat: 'Áudio', qty: 1, alloc: 1, s: 'ok' },
                      { n: 'Cabo XLR 10m (lote)', c: 'MMD-CAB-L012', cat: 'Cabo', qty: 40, alloc: 32, s: 'partial' },
                      { n: 'Cabo Powercon 5m', c: 'MMD-CAB-L004', cat: 'Cabo', qty: 30, alloc: 30, s: 'ok' },
                      { n: 'Box Truss Q30 3m', c: 'MMD-EST-0009', cat: 'Estrutura', qty: 12, alloc: 0, s: 'missing' },
                      { n: 'Máquina de fumaça Antari', c: 'MMD-EFE-0002', cat: 'Efeito', qty: 2, alloc: 2, s: 'ok' },
                    ].map((r, i) => (
                      <PackingRow key={i} {...r} />
                    ))}
                  </tbody>
                </table>
              </div>
            </GlassCard>
          </div>
        </div>
      </div>
    </div>
  );
}

function PackingRow({ n, c, cat, qty, alloc, s }) {
  const statusMap = {
    ok: { color: 'var(--accent-green)', label: 'Pronto' },
    partial: { color: 'var(--accent-amber)', label: `${alloc}/${qty}` },
    missing: { color: 'var(--accent-red)', label: 'Faltando' },
  };
  const st = statusMap[s];
  return (
    <tr style={{ borderTop: '1px solid var(--glass-border)' }}>
      <td style={{ padding: '12px', color: 'var(--fg-0)', fontWeight: 500 }}>{n}</td>
      <td style={{ padding: '12px' }} className="mono"><span style={{ fontSize: 11, color: 'var(--fg-2)' }}>{c}</span></td>
      <td style={{ padding: '12px', color: 'var(--fg-1)' }}>{cat}</td>
      <td style={{ padding: '12px' }} className="mono"><span style={{ fontSize: 12, color: 'var(--fg-1)' }}>{qty}</span></td>
      <td style={{ padding: '12px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 60, height: 4, borderRadius: 2, background: 'var(--glass-border)', overflow: 'hidden' }}>
            <div style={{ width: `${(alloc/qty)*100}%`, height: '100%', background: st.color }} />
          </div>
          <span className="mono" style={{ fontSize: 11, color: 'var(--fg-2)' }}>{alloc}/{qty}</span>
        </div>
      </td>
      <td style={{ padding: '12px' }}>
        <span style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          fontSize: 11, color: st.color, fontWeight: 500,
          padding: '3px 10px', borderRadius: 999,
          background: `color-mix(in oklch, ${st.color} 15%, transparent)`,
          border: `1px solid color-mix(in oklch, ${st.color} 30%, transparent)`,
        }}><StatusDot color={st.color} size={6} glow={false} /> {st.label}</span>
      </td>
      <td style={{ padding: '12px', color: 'var(--fg-3)', width: 20 }}>{Icons.dot3}</td>
    </tr>
  );
}

// ─────────────────────────────────────────────────────────
// V2 — Calendar timeline view
// ─────────────────────────────────────────────────────────
function ProjectsV2() {
  const days = ['21', '22', '23', '24', '25', '26', '27', '28', '29', '30', '01', '02', '03', '04', '05'];
  const months = ['abr', 'abr', 'abr', 'abr', 'abr', 'abr', 'abr', 'abr', 'abr', 'abr', 'mai', 'mai', 'mai', 'mai', 'mai'];
  const weekdays = ['qua', 'qui', 'sex', 'sáb', 'dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom', 'seg', 'ter', 'qua'];

  const projects = [
    { name: 'Casamento Santos & Oliveira', start: 2, dur: 2, items: 214, color: 'var(--accent-cyan)', r: 87 },
    { name: 'Feira Tech SP', start: 7, dur: 3, items: 340, color: 'var(--accent-violet)', r: 62 },
    { name: 'Show Banda Neon', start: 11, dur: 1, items: 128, color: 'var(--accent-green)', r: 100 },
    { name: 'Corporativo ABC', start: 14, dur: 1, items: 89, color: 'var(--accent-amber)', r: 45 },
  ];

  return (
    <div style={{ width: DASH_W, height: DASH_H, position: 'relative', background: 'var(--bg-0)' }}>
      <Caustic />
      <SideRail active="projects" />

      <div style={{ position: 'absolute', left: 80, right: 0, top: 0, bottom: 0, padding: '28px 32px', overflow: 'hidden' }}>
        <TopBar />

        <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginTop: 24 }}>
          <div style={{ fontSize: 22, fontWeight: 500, letterSpacing: -0.4 }}>Cronograma</div>
          <GlassPill><span className="mono" style={{ fontSize: 11 }}>abril · maio 2026</span></GlassPill>
          <div style={{ flex: 1 }} />
          <GhostBtn small>Mês</GhostBtn>
          <GhostBtn small>Semana</GhostBtn>
          <PrimaryBtn small>+ Novo projeto</PrimaryBtn>
        </div>

        {/* Calendar */}
        <GlassCard style={{ marginTop: 18, padding: 0, overflow: 'hidden' }}>
          {/* days header */}
          <div style={{ display: 'grid', gridTemplateColumns: `200px repeat(${days.length}, 1fr)`, borderBottom: '1px solid var(--glass-border)' }}>
            <div style={{ padding: 14, color: 'var(--fg-3)', fontSize: 11 }} className="mono">PROJETO</div>
            {days.map((d, i) => (
              <div key={i} style={{
                padding: '10px 0', textAlign: 'center',
                borderLeft: '1px solid var(--glass-border)',
                background: i === 2 ? 'color-mix(in oklch, var(--accent-cyan) 10%, transparent)' : 'transparent',
              }}>
                <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.08 }}>{weekdays[i]}</div>
                <div style={{ fontSize: 15, color: 'var(--fg-0)', fontWeight: 500, marginTop: 2 }}>{d}</div>
                <div className="mono" style={{ fontSize: 9, color: 'var(--fg-3)' }}>{months[i]}</div>
              </div>
            ))}
          </div>

          {/* rows */}
          {projects.map((p, i) => (
            <div key={i} style={{ display: 'grid', gridTemplateColumns: `200px repeat(${days.length}, 1fr)`, borderBottom: '1px solid var(--glass-border)', height: 76, position: 'relative' }}>
              <div style={{ padding: 14, display: 'flex', alignItems: 'center', gap: 10 }}>
                <Ring value={p.r} size={30} stroke={3} />
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontSize: 12, fontWeight: 500, color: 'var(--fg-0)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{p.name}</div>
                  <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)' }}>{p.items} itens</div>
                </div>
              </div>
              {days.map((_, j) => (
                <div key={j} style={{ borderLeft: '1px solid var(--glass-border)' }} />
              ))}
              {/* event bar */}
              <div style={{
                position: 'absolute', top: 18, height: 40,
                left: `calc(200px + (100% - 200px) / ${days.length} * ${p.start})`,
                width: `calc((100% - 200px) / ${days.length} * ${p.dur})`,
                borderRadius: 12, padding: '0 14px',
                display: 'flex', alignItems: 'center', gap: 10,
                background: `color-mix(in oklch, ${p.color} 22%, transparent)`,
                border: `1px solid color-mix(in oklch, ${p.color} 40%, transparent)`,
                backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
                boxShadow: `inset 0 1px 0 rgba(255,255,255,0.15)`,
              }}>
                <StatusDot color={p.color} size={6} />
                <span style={{ fontSize: 12, color: 'var(--fg-0)', fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{p.name}</span>
              </div>
            </div>
          ))}
        </GlassCard>

        {/* Availability alert strip */}
        <GlassCard style={{ marginTop: 18, padding: '16px 20px', display: 'flex', alignItems: 'center', gap: 16 }}>
          <IconBox glyph={Icons.warn} size={36} tint="color-mix(in oklch, var(--accent-amber) 20%, transparent)" color="var(--accent-amber)" />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--fg-0)' }}>Conflito de disponibilidade detectado</div>
            <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 2 }}>Feira Tech SP e Casamento Santos compartilham 12 Moving Heads nos dias 28–29.abr. <span style={{ color: 'var(--accent-cyan)' }}>Ver detalhes →</span></div>
          </div>
          <GhostBtn small>Resolver</GhostBtn>
        </GlassCard>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────
// V3. Kanban-style lanes (status de projeto)
// ─────────────────────────────────────────────────────────
function ProjectsV3() {
  const lanes = [
    { name: 'Planejado', count: 3, color: 'var(--fg-3)', cards: [
      { t: 'Show Banda Neon', d: '02.mai · 21h', items: 128, r: 100 },
      { t: 'Aniversário XV anos', d: '12.mai · 20h', items: 87, r: 0 },
      { t: 'Igreja Presbiteriana', d: '18.mai · 10h', items: 42, r: 0 },
    ]},
    { name: 'Em montagem', count: 2, color: 'var(--accent-cyan)', cards: [
      { t: 'Casamento Santos', d: '23.abr · 18h', items: 214, r: 87, highlight: true },
      { t: 'Feira Tech SP', d: '28.abr · 09h', items: 340, r: 62 },
    ]},
    { name: 'Em campo', count: 1, color: 'var(--accent-violet)', cards: [
      { t: 'Corporativo ABC', d: '21.abr · em curso', items: 89, r: 100 },
    ]},
    { name: 'Retornando', count: 1, color: 'var(--accent-amber)', cards: [
      { t: 'Festival Outono', d: '20.abr · retorno', items: 178, r: 94 },
    ]},
  ];

  return (
    <div style={{ width: DASH_W, height: DASH_H, position: 'relative', background: 'var(--bg-0)' }}>
      <Caustic />
      <SideRail active="projects" />

      <div style={{ position: 'absolute', left: 80, right: 0, top: 0, bottom: 0, padding: '28px 32px', overflow: 'hidden' }}>
        <TopBar />

        <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginTop: 24, marginBottom: 20 }}>
          <div style={{ fontSize: 22, fontWeight: 500, letterSpacing: -0.4 }}>Projetos</div>
          <GlassPill><span className="mono" style={{ fontSize: 11 }}>7 ativos</span></GlassPill>
          <div style={{ flex: 1 }} />
          <div className="glass" style={{ height: 34, borderRadius: 999, padding: '0 14px', display: 'flex', alignItems: 'center', gap: 8, color: 'var(--fg-2)', fontSize: 12, minWidth: 200 }}>
            {Icons.search}<span>Buscar projeto…</span>
          </div>
          <PrimaryBtn small>+ Novo</PrimaryBtn>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 14, height: 'calc(100% - 130px)' }}>
          {lanes.map((lane, i) => (
            <div key={i} style={{ display: 'flex', flexDirection: 'column', gap: 10, minHeight: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '0 6px' }}>
                <StatusDot color={lane.color} size={8} />
                <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--fg-0)' }}>{lane.name}</div>
                <div className="mono" style={{ fontSize: 11, color: 'var(--fg-3)' }}>{lane.count}</div>
                <div style={{ flex: 1 }} />
                <span style={{ color: 'var(--fg-3)', fontSize: 16, lineHeight: 1 }}>+</span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10, overflow: 'auto', minHeight: 0, paddingBottom: 20 }}>
                {lane.cards.map((c, j) => (
                  <GlassCard key={j} strong={c.highlight} style={{ padding: 14, position: 'relative' }}>
                    {c.highlight && <div style={{ position: 'absolute', inset: -1, borderRadius: 'var(--r-lg)', padding: 1, background: 'linear-gradient(135deg, var(--accent-cyan), var(--accent-violet))', WebkitMask: 'linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)', WebkitMaskComposite: 'xor', maskComposite: 'exclude', pointerEvents: 'none' }} />}
                    <div style={{ position: 'relative' }}>
                      <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--fg-0)', marginBottom: 4 }}>{c.t}</div>
                      <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', marginBottom: 14 }}>{c.d}</div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        <Ring value={c.r} size={36} stroke={3} />
                        <div>
                          <div style={{ fontSize: 11, color: 'var(--fg-3)' }}>itens</div>
                          <div className="mono" style={{ fontSize: 13, color: 'var(--fg-1)', fontWeight: 500 }}>{c.items}</div>
                        </div>
                        <div style={{ flex: 1 }} />
                        <div style={{ display: 'flex' }}>
                          {['G', 'C', 'M'].map((a, k) => (
                            <div key={k} style={{
                              width: 22, height: 22, borderRadius: '50%',
                              background: 'var(--glass-bg-strong)',
                              border: '1px solid var(--bg-0)',
                              marginLeft: k === 0 ? 0 : -6,
                              display: 'flex', alignItems: 'center', justifyContent: 'center',
                              fontSize: 10, color: 'var(--fg-1)', fontWeight: 500,
                            }}>{a}</div>
                          ))}
                        </div>
                      </div>
                    </div>
                  </GlassCard>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { ProjectsV1, ProjectsV2, ProjectsV3 });
