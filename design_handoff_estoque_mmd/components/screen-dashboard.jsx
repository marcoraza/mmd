// screen-dashboard.jsx — Web Dashboard, 3 variations
// Hero metric: Próximo evento + readiness %

const DASH_W = 1280;
const DASH_H = 820;

// ─────────────────────────────────────────────────────────
// V1 — Hero Ring + Grid of glass panels
// ─────────────────────────────────────────────────────────
function DashboardV1() {
  return (
    <div style={{ width: DASH_W, height: DASH_H, position: 'relative', background: 'var(--bg-0)' }}>
      <Caustic orb3 />

      {/* Side rail */}
      <SideRail active="dashboard" />

      {/* Main */}
      <div style={{ position: 'absolute', left: 80, right: 0, top: 0, bottom: 0, padding: '28px 40px 32px', overflow: 'hidden' }}>
        <TopBar />

        {/* hero row */}
        <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr 1fr', gap: 18, marginTop: 24 }}>
          <HeroEventCard />
          <MetricCard label="VALOR PATRIMONIAL" value="R$ 372k" sub="+R$ 8.2k este mês" trend={[10,12,11,14,15,14,18]} />
          <MetricCard label="DESGASTE MÉDIO" value="3.8" sub="de 5 · saúde boa" trend={[3.5,3.6,3.6,3.7,3.7,3.8,3.8]} color="var(--accent-green)" />
        </div>

        {/* second row */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: 18, marginTop: 18 }}>
          <StatusTile label="Disponível" count="847" color="var(--accent-green)" />
          <StatusTile label="Em campo" count="142" color="var(--accent-cyan)" />
          <StatusTile label="Manutenção" count="38" color="var(--accent-amber)" />
          <StatusTile label="Crítico" count="7" color="var(--accent-red)" />
        </div>

        {/* bottom row */}
        <div style={{ display: 'grid', gridTemplateColumns: '1.3fr 1fr', gap: 18, marginTop: 18 }}>
          <CategoryBreakdown />
          <RecentMovements />
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────
// V2 — Cinematic: huge readiness number, minimal chrome
// ─────────────────────────────────────────────────────────
function DashboardV2() {
  return (
    <div style={{ width: DASH_W, height: DASH_H, position: 'relative', background: 'var(--bg-0)' }}>
      <Caustic orb3 />

      <SideRail active="dashboard" compact />

      <div style={{ position: 'absolute', left: 64, right: 0, top: 0, bottom: 0, padding: '28px 48px', overflow: 'hidden' }}>
        <TopBar />

        {/* Cinematic hero */}
        <div style={{ marginTop: 36, display: 'flex', alignItems: 'flex-end', gap: 48, flexWrap: 'wrap' }}>
          <div style={{ flex: '1 1 560px' }}>
            <div className="mono" style={{ fontSize: 11, color: 'var(--fg-2)', letterSpacing: 0.12, textTransform: 'uppercase', marginBottom: 16 }}>
              Próximo evento · em 2 dias 14h
            </div>
            <div style={{ fontSize: 56, fontWeight: 500, letterSpacing: -1.5, lineHeight: 1.05, color: 'var(--fg-0)' }}>
              Casamento<br/>
              <span style={{ color: 'var(--fg-2)' }}>Santos & Oliveira</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 24, marginTop: 20, color: 'var(--fg-1)', fontSize: 14 }}>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>{Icons.calendar} 23.abr · 18h</span>
              <span>Jardim Botânico · SP</span>
              <span className="mono" style={{ color: 'var(--fg-2)' }}>214 itens</span>
            </div>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
            <Ring value={87} size={240} stroke={14} label="readiness" />
            <div style={{ fontSize: 13, color: 'var(--fg-2)' }}>28 itens a verificar</div>
          </div>
        </div>

        {/* Glass stat strip — readable list instead of tiles */}
        <div className="glass" style={{ marginTop: 40, borderRadius: 'var(--r-lg)', padding: 0, display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', overflow: 'hidden' }}>
          {[
            { l: 'Disponível', v: '847', c: 'var(--accent-green)' },
            { l: 'Em campo', v: '142', c: 'var(--accent-cyan)' },
            { l: 'Retornando', v: '30', c: 'var(--accent-violet)' },
            { l: 'Manutenção', v: '38', c: 'var(--accent-amber)' },
            { l: 'Patrimônio', v: 'R$ 372k', c: 'var(--fg-0)', mono: true },
          ].map((s, i) => (
            <div key={i} style={{ padding: '22px 24px', borderLeft: i === 0 ? 'none' : '1px solid var(--glass-border)' }}>
              <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', letterSpacing: 0.1, textTransform: 'uppercase' }}>{s.l}</div>
              <div style={{
                fontSize: 28, fontWeight: 500, marginTop: 4, color: s.c,
                fontFamily: s.mono ? 'var(--font-sans)' : 'var(--font-sans)',
                letterSpacing: -0.5,
              }}>{s.v}</div>
            </div>
          ))}
        </div>

        {/* Upcoming events rail */}
        <div style={{ marginTop: 36 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
            <div style={{ fontSize: 14, color: 'var(--fg-1)', fontWeight: 500 }}>Próximos eventos</div>
            <div className="mono" style={{ fontSize: 11, color: 'var(--fg-3)' }}>8 agendados</div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 14 }}>
            {[
              { t: 'Casamento Santos', d: '23.abr · 18h', r: 87, n: 214 },
              { t: 'Feira Tech SP', d: '28.abr · 09h', r: 62, n: 340 },
              { t: 'Show Banda Neon', d: '02.mai · 21h', r: 100, n: 128 },
              { t: 'Corporativo ABC', d: '05.mai · 14h', r: 45, n: 89 },
            ].map((e, i) => (
              <GlassCard key={i} style={{ padding: 18 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
                  <Ring value={e.r} size={44} stroke={4} />
                  <div>
                    <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--fg-0)' }}>{e.t}</div>
                    <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', marginTop: 2 }}>{e.d}</div>
                  </div>
                </div>
                <div style={{ fontSize: 11, color: 'var(--fg-3)' }}>{e.n} itens no packing list</div>
              </GlassCard>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────
// V3 — Operational: focus on actionable queue + live feed
// ─────────────────────────────────────────────────────────
function DashboardV3() {
  return (
    <div style={{ width: DASH_W, height: DASH_H, position: 'relative', background: 'var(--bg-0)' }}>
      <Caustic />

      <SideRail active="dashboard" />

      <div style={{ position: 'absolute', left: 80, right: 0, top: 0, bottom: 0, padding: '28px 40px', overflow: 'hidden' }}>
        <TopBar />

        <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 20, marginTop: 24, height: 'calc(100% - 80px)' }}>
          {/* Left: giant event card + action queue */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
            {/* Event hero */}
            <GlassCard strong style={{ padding: 28, position: 'relative', overflow: 'hidden' }}>
              <div style={{ position: 'absolute', right: -60, top: -60, width: 300, height: 300, borderRadius: '50%',
                background: 'radial-gradient(circle, oklch(0.75 0.18 210 / 0.35), transparent 60%)', filter: 'blur(20px)' }} />
              <div style={{ position: 'relative', display: 'flex', alignItems: 'center', gap: 28 }}>
                <Ring value={87} size={160} stroke={10} label="readiness" />
                <div style={{ flex: 1 }}>
                  <div className="mono" style={{ fontSize: 11, color: 'var(--accent-cyan)', letterSpacing: 0.12, textTransform: 'uppercase' }}>Próximo evento</div>
                  <div style={{ fontSize: 32, fontWeight: 500, color: 'var(--fg-0)', marginTop: 6, letterSpacing: -0.8 }}>Casamento Santos & Oliveira</div>
                  <div style={{ display: 'flex', gap: 20, marginTop: 10, color: 'var(--fg-2)', fontSize: 13 }}>
                    <span>23.abr · 18h</span>
                    <span>Jardim Botânico, SP</span>
                    <span className="mono">214 itens</span>
                  </div>
                  <div style={{ display: 'flex', gap: 8, marginTop: 16 }}>
                    <PrimaryBtn>Montar packing list</PrimaryBtn>
                    <GhostBtn>Abrir evento</GhostBtn>
                  </div>
                </div>
              </div>
            </GlassCard>

            {/* Action queue */}
            <GlassCard style={{ padding: 20, flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
                <div style={{ fontSize: 14, fontWeight: 500 }}>Precisa da sua atenção</div>
                <GlassPill><span className="mono" style={{ fontSize: 11 }}>12 itens</span></GlassPill>
              </div>
              <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column', gap: 8 }}>
                <AlertRow icon={Icons.warn} color="var(--accent-red)" title="Mesa Yamaha MG16XU — não retornou" sub="Projeto: Festival Outono · vence hoje" />
                <AlertRow icon={Icons.warn} color="var(--accent-amber)" title="4 Moving Heads com desgaste crítico" sub="Recomendado inspeção antes do próximo evento" />
                <AlertRow icon={Icons.rfid} color="var(--accent-cyan)" title="28 itens do Casamento Santos precisam de tag RFID" sub="Vincular antes do packing" />
                <AlertRow icon={Icons.package} color="var(--accent-violet)" title="18 cabos XLR retornaram sem lote" sub="Reagrupar em lote LOT-XLR-0042" />
              </div>
            </GlassCard>
          </div>

          {/* Right: live feed */}
          <GlassCard style={{ padding: 20, display: 'flex', flexDirection: 'column' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
              <div style={{ fontSize: 14, fontWeight: 500 }}>Ao vivo</div>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11, color: 'var(--fg-2)' }}>
                <StatusDot color="var(--accent-green)" size={6} /> <span className="mono">realtime</span>
              </span>
            </div>
            <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column', gap: 12 }}>
              {[
                { t: 'agora', op: 'Gabriel', a: 'escaneou RFID', target: '14 itens', method: 'lote' },
                { t: '2min', op: 'Carla', a: 'confirmou retorno', target: 'Caixa JBL SRX815P', method: 'QR' },
                { t: '5min', op: 'Sistema', a: 'detectou desgaste', target: 'Par LED 18x10W #012', method: 'auto' },
                { t: '12min', op: 'Gabriel', a: 'montou packing', target: '89 itens · Festival', method: null },
                { t: '18min', op: 'Marcelo', a: 'criou projeto', target: 'Casamento Santos', method: null },
                { t: '31min', op: 'Carla', a: 'escaneou RFID', target: '32 itens', method: 'lote' },
                { t: '1h', op: 'Gabriel', a: 'marcou defeito', target: 'Microfone Shure #008', method: null },
              ].map((f, i) => (
                <div key={i} style={{ display: 'flex', gap: 10, fontSize: 12 }}>
                  <div className="mono" style={{ color: 'var(--fg-3)', width: 34, flexShrink: 0 }}>{f.t}</div>
                  <div style={{ color: 'var(--fg-1)', lineHeight: 1.5 }}>
                    <b style={{ color: 'var(--fg-0)', fontWeight: 500 }}>{f.op}</b> {f.a} <b style={{ color: 'var(--fg-0)', fontWeight: 500 }}>{f.target}</b>
                    {f.method && <span className="mono" style={{ color: 'var(--accent-cyan)', marginLeft: 6, fontSize: 10 }}>· {f.method}</span>}
                  </div>
                </div>
              ))}
            </div>
          </GlassCard>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────
// Shared dashboard chrome
// ─────────────────────────────────────────────────────────
function SideRail({ active, compact = false }) {
  const items = [
    { id: 'dashboard', icon: <svg width="18" height="18" viewBox="0 0 18 18" fill="none"><rect x="2" y="2" width="6" height="6" rx="1.5" stroke="currentColor" strokeWidth="1.3"/><rect x="10" y="2" width="6" height="6" rx="1.5" stroke="currentColor" strokeWidth="1.3"/><rect x="2" y="10" width="6" height="6" rx="1.5" stroke="currentColor" strokeWidth="1.3"/><rect x="10" y="10" width="6" height="6" rx="1.5" stroke="currentColor" strokeWidth="1.3"/></svg>, label: 'Dashboard' },
    { id: 'inventory', icon: Icons.box, label: 'Inventário' },
    { id: 'projects', icon: Icons.package, label: 'Projetos' },
    { id: 'scan', icon: Icons.rfid, label: 'RFID' },
    { id: 'reports', icon: <svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M3 15V5M9 15V2M15 15V9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/></svg>, label: 'Relatórios' },
  ];
  const w = compact ? 64 : 80;
  return (
    <div style={{
      position: 'absolute', left: 0, top: 0, bottom: 0, width: w,
      display: 'flex', flexDirection: 'column', alignItems: 'center',
      padding: '20px 0', gap: 4, zIndex: 2,
      borderRight: '1px solid var(--glass-border)',
      background: 'rgba(0,0,0,0.15)',
      backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
    }}>
      {/* Logo mark */}
      <div style={{
        width: 40, height: 40, borderRadius: 12,
        background: 'linear-gradient(135deg, var(--accent-cyan), var(--accent-violet))',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontFamily: 'var(--font-mono)', fontWeight: 700, color: '#fff', fontSize: 14,
        letterSpacing: -0.5, marginBottom: 16,
        boxShadow: '0 4px 12px oklch(0.70 0.17 250 / 0.4)',
      }}>M</div>
      {items.map(it => (
        <div key={it.id} style={{
          width: 44, height: 44, borderRadius: 12,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: it.id === active ? 'var(--fg-0)' : 'var(--fg-3)',
          background: it.id === active ? 'var(--glass-bg-strong)' : 'transparent',
          border: it.id === active ? '1px solid var(--glass-border-strong)' : '1px solid transparent',
          cursor: 'pointer',
        }}>{it.icon}</div>
      ))}
      <div style={{ flex: 1 }} />
      <div style={{
        width: 36, height: 36, borderRadius: '50%',
        background: 'var(--glass-bg-strong)',
        border: '1px solid var(--glass-border-strong)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 12, color: 'var(--fg-1)', fontWeight: 600,
      }}>MS</div>
    </div>
  );
}

function TopBar() {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 16, height: 48, position: 'relative', zIndex: 1 }}>
      <div>
        <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.12, textTransform: 'uppercase' }}>Estoque Inteligente</div>
        <div style={{ fontSize: 20, fontWeight: 500, letterSpacing: -0.3, color: 'var(--fg-0)', marginTop: 2 }}>Bom dia, Marcelo</div>
      </div>
      <div style={{ flex: 1 }} />
      <div className="glass" style={{
        display: 'flex', alignItems: 'center', gap: 8, padding: '0 14px',
        height: 36, borderRadius: 999, color: 'var(--fg-2)', fontSize: 13, minWidth: 260,
      }}>
        {Icons.search}
        <span style={{ flex: 1 }}>Buscar item, serial, tag…</span>
        <span className="mono" style={{ fontSize: 10, opacity: 0.6 }}>⌘K</span>
      </div>
      <GlassPill><span style={{ color: 'var(--fg-1)' }}>{Icons.bell}</span><span className="mono" style={{ fontSize: 11, color: 'var(--accent-cyan)' }}>3</span></GlassPill>
    </div>
  );
}

function HeroEventCard() {
  return (
    <GlassCard strong style={{ padding: 22, position: 'relative', overflow: 'hidden', minHeight: 180 }}>
      <div style={{ position: 'absolute', right: -40, top: -40, width: 200, height: 200, borderRadius: '50%',
        background: 'radial-gradient(circle, oklch(0.75 0.18 210 / 0.3), transparent 60%)', filter: 'blur(20px)' }} />
      <div style={{ position: 'relative', display: 'flex', gap: 20, alignItems: 'center', height: '100%' }}>
        <Ring value={87} size={130} stroke={8} label="readiness" />
        <div style={{ flex: 1 }}>
          <div className="mono" style={{ fontSize: 10, color: 'var(--accent-cyan)', letterSpacing: 0.12, textTransform: 'uppercase' }}>Próximo evento · em 2d 14h</div>
          <div style={{ fontSize: 22, fontWeight: 500, color: 'var(--fg-0)', marginTop: 6, letterSpacing: -0.4, lineHeight: 1.2 }}>Casamento Santos & Oliveira</div>
          <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 8 }}>23.abr · 18h · Jardim Botânico</div>
          <div style={{ display: 'flex', gap: 6, marginTop: 14 }}>
            <PrimaryBtn small>Packing list</PrimaryBtn>
            <GhostBtn small>Detalhes</GhostBtn>
          </div>
        </div>
      </div>
    </GlassCard>
  );
}

function MetricCard({ label, value, sub, trend, color = 'var(--accent-cyan)' }) {
  return (
    <GlassCard style={{ padding: 22, minHeight: 180, display: 'flex', flexDirection: 'column' }}>
      <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', letterSpacing: 0.12 }}>{label}</div>
      <div style={{ fontSize: 32, fontWeight: 500, letterSpacing: -0.8, marginTop: 10, color: 'var(--fg-0)' }}>{value}</div>
      <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 4 }}>{sub}</div>
      <div style={{ flex: 1 }} />
      <Sparkline data={trend} width={200} height={36} color={color} />
    </GlassCard>
  );
}

function StatusTile({ label, count, color }) {
  return (
    <GlassCard style={{ padding: 18, display: 'flex', alignItems: 'center', gap: 14 }}>
      <StatusDot color={color} size={10} />
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 12, color: 'var(--fg-2)' }}>{label}</div>
        <div style={{ fontSize: 22, fontWeight: 500, color: 'var(--fg-0)', marginTop: 2, letterSpacing: -0.5 }}>{count}</div>
      </div>
    </GlassCard>
  );
}

function CategoryBreakdown() {
  const cats = [
    { name: 'Cabo', count: 465, pct: 44, color: 'oklch(0.75 0.14 210)' },
    { name: 'Iluminação', count: 198, pct: 19, color: 'oklch(0.75 0.17 60)' },
    { name: 'Áudio', count: 172, pct: 16, color: 'oklch(0.70 0.17 295)' },
    { name: 'Energia', count: 98, pct: 9, color: 'oklch(0.75 0.17 150)' },
    { name: 'Estrutura', count: 64, pct: 6, color: 'oklch(0.70 0.14 30)' },
    { name: 'Efeito', count: 38, pct: 4, color: 'oklch(0.72 0.14 330)' },
    { name: 'Outros', count: 29, pct: 3, color: 'oklch(0.60 0.03 250)' },
  ];
  return (
    <GlassCard style={{ padding: 22 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
        <div style={{ fontSize: 14, fontWeight: 500 }}>Categorias</div>
        <div className="mono" style={{ fontSize: 11, color: 'var(--fg-3)' }}>1.064 itens · 8 categorias</div>
      </div>
      {/* stacked bar */}
      <div style={{ display: 'flex', height: 6, borderRadius: 3, overflow: 'hidden', marginBottom: 18, background: 'var(--glass-border)' }}>
        {cats.map((c, i) => <div key={i} style={{ flex: c.pct, background: c.color }} />)}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px 24px' }}>
        {cats.map((c, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <StatusDot color={c.color} size={8} glow={false} />
            <div style={{ fontSize: 13, color: 'var(--fg-1)', flex: 1 }}>{c.name}</div>
            <div className="mono" style={{ fontSize: 12, color: 'var(--fg-2)' }}>{c.count}</div>
            <div className="mono" style={{ fontSize: 11, color: 'var(--fg-3)', width: 32, textAlign: 'right' }}>{c.pct}%</div>
          </div>
        ))}
      </div>
    </GlassCard>
  );
}

function RecentMovements() {
  const items = [
    { t: 'agora', action: 'RFID lote', name: '14 itens · Festival Out.', icon: Icons.rfid, color: 'var(--accent-cyan)' },
    { t: '2min', action: 'Retorno', name: 'Caixa JBL SRX815P', icon: Icons.check, color: 'var(--accent-green)' },
    { t: '18min', action: 'Defeito', name: 'Par LED #012', icon: Icons.warn, color: 'var(--accent-amber)' },
    { t: '1h', action: 'Saída', name: '89 itens · Corporativo', icon: Icons.arrow, color: 'var(--accent-violet)' },
    { t: '2h', action: 'Vinculação', name: 'Tag RFID → Mic #008', icon: Icons.zap, color: 'var(--accent-cyan)' },
  ];
  return (
    <GlassCard style={{ padding: 22 }}>
      <div style={{ fontSize: 14, fontWeight: 500, marginBottom: 14 }}>Últimas movimentações</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {items.map((m, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <IconBox glyph={m.icon} size={32} tint="var(--glass-bg-strong)" color={m.color} />
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 12, color: 'var(--fg-3)' }}>{m.action}</div>
              <div style={{ fontSize: 13, color: 'var(--fg-0)' }}>{m.name}</div>
            </div>
            <div className="mono" style={{ fontSize: 11, color: 'var(--fg-3)' }}>{m.t}</div>
          </div>
        ))}
      </div>
    </GlassCard>
  );
}

function AlertRow({ icon, color, title, sub }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12, padding: '10px 12px',
      background: 'var(--glass-bg)', borderRadius: 10, border: '1px solid var(--glass-border)',
    }}>
      <IconBox glyph={icon} size={30} tint={`color-mix(in oklch, ${color} 18%, transparent)`} color={color} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 13, color: 'var(--fg-0)', fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{title}</div>
        <div style={{ fontSize: 11, color: 'var(--fg-2)', marginTop: 2 }}>{sub}</div>
      </div>
      <span style={{ color: 'var(--fg-3)' }}>{Icons.chevron}</span>
    </div>
  );
}

function PrimaryBtn({ children, small }) {
  return (
    <button style={{
      border: 'none', padding: small ? '7px 14px' : '10px 18px', borderRadius: small ? 8 : 10,
      fontFamily: 'var(--font-sans)', fontWeight: 500, fontSize: small ? 12 : 13,
      color: '#fff', cursor: 'pointer',
      background: 'linear-gradient(180deg, oklch(0.78 0.14 210), oklch(0.68 0.15 220))',
      boxShadow: '0 4px 12px oklch(0.70 0.14 220 / 0.35), inset 0 1px 0 rgba(255,255,255,0.25)',
    }}>{children}</button>
  );
}
function GhostBtn({ children, small }) {
  return (
    <button className="glass" style={{
      padding: small ? '7px 14px' : '10px 18px', borderRadius: small ? 8 : 10,
      fontFamily: 'var(--font-sans)', fontWeight: 500, fontSize: small ? 12 : 13,
      color: 'var(--fg-0)', cursor: 'pointer', background: 'var(--glass-bg)',
    }}>{children}</button>
  );
}

Object.assign(window, { DashboardV1, DashboardV2, DashboardV3, DASH_W, DASH_H, PrimaryBtn, GhostBtn, SideRail, TopBar });
