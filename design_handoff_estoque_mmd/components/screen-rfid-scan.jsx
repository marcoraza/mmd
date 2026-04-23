// screen-rfid-scan.jsx — iOS RFID Scan (hero moment), 3 variations
// Uses IOSDevice + custom overlays

// ─────────────────────────────────────────────────────────
// V1 — Live particle cloud (HERO moment)
// Particles radiate outward as tags are read. Each particle = 1 tag.
// ─────────────────────────────────────────────────────────
function RfidScanV1() {
  // fixed pseudo-random particle positions
  const particles = [
    { x: 50, y: 45, r: 3, delay: 0 }, { x: 70, y: 30, r: 2, delay: 0.2 },
    { x: 30, y: 35, r: 2.5, delay: 0.1 }, { x: 80, y: 55, r: 2, delay: 0.3 },
    { x: 20, y: 60, r: 2.5, delay: 0.15 }, { x: 60, y: 20, r: 3, delay: 0.25 },
    { x: 40, y: 70, r: 2, delay: 0.4 }, { x: 85, y: 40, r: 2.5, delay: 0.35 },
    { x: 15, y: 45, r: 2, delay: 0.5 }, { x: 75, y: 70, r: 3, delay: 0.45 },
    { x: 55, y: 75, r: 2, delay: 0.55 }, { x: 25, y: 20, r: 2.5, delay: 0.05 },
    { x: 90, y: 20, r: 2, delay: 0.6 }, { x: 10, y: 30, r: 2, delay: 0.15 },
    { x: 45, y: 25, r: 2.5, delay: 0.3 }, { x: 65, y: 60, r: 3, delay: 0.4 },
    { x: 35, y: 55, r: 2, delay: 0.5 }, { x: 50, y: 85, r: 2.5, delay: 0.2 },
  ];

  return (
    <IOSDevice dark width={402} height={874}>
      {/* caustic bg */}
      <div style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
        <div style={{ position: 'absolute', width: '120%', aspectRatio: 1, left: '-10%', top: '-20%',
          background: 'radial-gradient(circle, oklch(0.72 0.20 210) 0%, transparent 60%)',
          filter: 'blur(50px)', opacity: 0.5 }} />
        <div style={{ position: 'absolute', width: '100%', aspectRatio: 1, right: '-30%', bottom: '-20%',
          background: 'radial-gradient(circle, oklch(0.65 0.22 295) 0%, transparent 60%)',
          filter: 'blur(50px)', opacity: 0.45 }} />
      </div>

      {/* header */}
      <div style={{ position: 'absolute', top: 60, left: 0, right: 0, padding: '0 20px', zIndex: 5 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{
            width: 36, height: 36, borderRadius: 12,
            background: 'rgba(255,255,255,0.1)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
            border: '1px solid rgba(255,255,255,0.15)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff',
          }}>{Icons.chevron && <svg width="10" height="10" viewBox="0 0 10 10" fill="none" style={{ transform: 'rotate(180deg)' }}><path d="M3.5 2L6.5 5L3.5 8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>}</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.6)', fontFamily: 'var(--font-mono)', letterSpacing: 0.08, textTransform: 'uppercase' }}>Lendo RFID</div>
            <div style={{ fontSize: 15, color: '#fff', fontWeight: 500 }}>Casamento Santos</div>
          </div>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '5px 10px', borderRadius: 999,
            background: 'rgba(52, 199, 89, 0.22)', border: '1px solid rgba(52, 199, 89, 0.35)',
            fontSize: 10, color: '#6dd18e', fontFamily: 'var(--font-mono)', letterSpacing: 0.08 }}>
            <StatusDot color="#6dd18e" size={5} /> LIVE
          </div>
        </div>
      </div>

      {/* Main scan area */}
      <div style={{ position: 'absolute', top: 120, left: 0, right: 0, height: 360, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        {/* concentric rings */}
        {[0.3, 0.55, 0.8, 1].map((s, i) => (
          <div key={i} style={{
            position: 'absolute', width: 300 * s, height: 300 * s, borderRadius: '50%',
            border: '1px solid rgba(120, 180, 255, 0.25)',
            boxShadow: i === 3 ? '0 0 40px rgba(120, 180, 255, 0.3)' : 'none',
          }} />
        ))}

        {/* Particles */}
        {particles.map((p, i) => (
          <div key={i} style={{
            position: 'absolute',
            left: `${p.x}%`, top: `${p.y}%`,
            width: p.r * 2, height: p.r * 2,
            borderRadius: '50%',
            background: 'oklch(0.85 0.14 210)',
            boxShadow: '0 0 10px oklch(0.85 0.14 210), 0 0 20px oklch(0.85 0.14 210)',
          }} />
        ))}

        {/* Central number */}
        <div style={{ position: 'relative', textAlign: 'center' }}>
          <div style={{ fontSize: 88, fontWeight: 300, letterSpacing: -4, color: '#fff', lineHeight: 1,
            textShadow: '0 0 40px rgba(120, 180, 255, 0.5)' }}>127</div>
          <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.6)', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase', marginTop: 4 }}>
            tags lidas · de 214
          </div>
          <div style={{ marginTop: 12, height: 4, borderRadius: 2, width: 180, margin: '12px auto 0', background: 'rgba(255,255,255,0.1)', overflow: 'hidden' }}>
            <div style={{ width: '59%', height: '100%', background: 'linear-gradient(90deg, #7cc4ff, #b794ff)', boxShadow: '0 0 10px #7cc4ff' }} />
          </div>
        </div>
      </div>

      {/* Glass panel — scan feed */}
      <div style={{ position: 'absolute', bottom: 140, left: 16, right: 16, borderRadius: 28, padding: 16,
        background: 'rgba(255,255,255,0.08)', backdropFilter: 'blur(40px) saturate(180%)', WebkitBackdropFilter: 'blur(40px) saturate(180%)',
        border: '1px solid rgba(255,255,255,0.12)', boxShadow: '0 20px 60px rgba(0,0,0,0.4)' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
          <div style={{ fontSize: 12, color: '#fff', fontWeight: 500 }}>Última leitura</div>
          <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)' }}>agora</div>
        </div>
        {[
          { n: 'Par LED 18x10W · #012', c: 'MMD-ILU-0042-012', s: 'ok' },
          { n: 'Cabo XLR 10m · lote', c: 'MMD-CAB-L012', s: 'ok' },
          { n: 'Moving Head #08', c: 'MMD-ILU-0088-008', s: 'warn' },
        ].map((r, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 0', borderTop: i === 0 ? 'none' : '1px solid rgba(255,255,255,0.08)' }}>
            <StatusDot color={r.s === 'ok' ? '#6dd18e' : '#ffb75c'} size={6} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 12, color: '#fff', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.n}</div>
              <div style={{ fontSize: 9, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)' }}>{r.c}</div>
            </div>
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none" style={{ color: r.s === 'ok' ? '#6dd18e' : '#ffb75c' }}>
              {r.s === 'ok' ? <path d="M2 6L5 9L10 3" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/> : <path d="M6 2v5M6 9v.01" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>}
            </svg>
          </div>
        ))}
      </div>

      {/* Big glass scan button */}
      <div style={{ position: 'absolute', bottom: 50, left: 0, right: 0, display: 'flex', justifyContent: 'center', zIndex: 5 }}>
        <div style={{ position: 'relative', width: 84, height: 84 }}>
          <div style={{ position: 'absolute', inset: -8, borderRadius: '50%',
            background: 'radial-gradient(circle, rgba(124, 196, 255, 0.4), transparent 70%)', filter: 'blur(12px)' }} />
          <div style={{
            position: 'relative', width: 84, height: 84, borderRadius: '50%',
            background: 'linear-gradient(180deg, rgba(255,255,255,0.25), rgba(255,255,255,0.08))',
            backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
            border: '1px solid rgba(255,255,255,0.3)',
            boxShadow: 'inset 0 2px 0 rgba(255,255,255,0.3), 0 10px 30px rgba(0,0,0,0.4)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff',
          }}>
            <div style={{ width: 24, height: 24 }}>{Icons.rfid}</div>
          </div>
        </div>
      </div>
    </IOSDevice>
  );
}

// ─────────────────────────────────────────────────────────
// V2 — Conventional list with live counter
// ─────────────────────────────────────────────────────────
function RfidScanV2() {
  return (
    <IOSDevice dark width={402} height={874}>
      {/* bg */}
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(ellipse at top, oklch(0.22 0.05 250) 0%, oklch(0.10 0.02 250) 60%)' }} />

      {/* nav */}
      <div style={{ position: 'absolute', top: 54, left: 0, right: 0, padding: '10px 16px', zIndex: 5 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <IOSGlassPill dark>
            <div style={{ padding: '0 12px', fontSize: 14, color: '#fff' }}>Cancelar</div>
          </IOSGlassPill>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.6)', fontFamily: 'var(--font-mono)', letterSpacing: 0.08, textTransform: 'uppercase' }}>RFID</div>
            <div style={{ fontSize: 14, color: '#fff', fontWeight: 600 }}>Leitura em lote</div>
          </div>
          <IOSGlassPill dark>
            <div style={{ padding: '0 14px', fontSize: 14, color: '#7cc4ff', fontWeight: 600 }}>OK</div>
          </IOSGlassPill>
        </div>
      </div>

      {/* Big count header */}
      <div style={{ position: 'absolute', top: 130, left: 0, right: 0, textAlign: 'center', padding: '0 20px' }}>
        <div style={{ fontSize: 72, fontWeight: 300, letterSpacing: -3, color: '#fff', lineHeight: 1 }}>127<span style={{ color: 'rgba(255,255,255,0.35)', fontSize: 36 }}>/214</span></div>
        <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.6)', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase', marginTop: 6 }}>Itens lidos</div>
        {/* Progress bar */}
        <div style={{ margin: '14px auto 0', width: '80%', height: 6, borderRadius: 3, background: 'rgba(255,255,255,0.08)', overflow: 'hidden' }}>
          <div style={{ width: '59%', height: '100%', background: 'linear-gradient(90deg, #7cc4ff, #b794ff)' }} />
        </div>
      </div>

      {/* Stats row */}
      <div style={{ position: 'absolute', top: 290, left: 16, right: 16, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
        {[
          { l: 'Na lista', v: '127', c: '#6dd18e' },
          { l: 'Faltando', v: '87', c: '#ffb75c' },
          { l: 'Fora', v: '0', c: 'rgba(255,255,255,0.5)' },
        ].map((s, i) => (
          <div key={i} style={{
            padding: '14px 10px', textAlign: 'center', borderRadius: 16,
            background: 'rgba(255,255,255,0.06)', backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
            border: '1px solid rgba(255,255,255,0.1)',
          }}>
            <div style={{ fontSize: 22, fontWeight: 500, color: s.c }}>{s.v}</div>
            <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)', letterSpacing: 0.08, textTransform: 'uppercase', marginTop: 2 }}>{s.l}</div>
          </div>
        ))}
      </div>

      {/* Scan list */}
      <div style={{ position: 'absolute', top: 380, left: 16, right: 16, bottom: 180, borderRadius: 28, overflow: 'hidden',
        background: 'rgba(255,255,255,0.05)', backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
        border: '1px solid rgba(255,255,255,0.1)' }}>
        <div style={{ padding: '12px 16px', borderBottom: '1px solid rgba(255,255,255,0.08)', display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: 13, color: '#fff', fontWeight: 500 }}>Feed</span>
          <div style={{ flex: 1 }} />
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 10, color: '#6dd18e', fontFamily: 'var(--font-mono)' }}>
            <StatusDot color="#6dd18e" size={5} /> LIVE
          </div>
        </div>
        <div style={{ padding: '4px 0' }}>
          {[
            { n: 'Par LED 18x10W', c: 'MMD-ILU-0042-012', t: 'agora' },
            { n: 'Cabo XLR 10m (lote)', c: 'MMD-CAB-L012', t: '1s', batch: 8 },
            { n: 'Moving Head Beam', c: 'MMD-ILU-0088-008', t: '2s' },
            { n: 'Caixa JBL VRX932', c: 'MMD-AUD-0011-004', t: '3s' },
            { n: 'Subwoofer SRX818', c: 'MMD-AUD-0024-002', t: '3s' },
            { n: 'Cabo Powercon 5m', c: 'MMD-CAB-L004', t: '4s', batch: 12 },
          ].map((r, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 16px', borderBottom: i === 5 ? 'none' : '0.5px solid rgba(255,255,255,0.06)' }}>
              <div style={{ width: 8, height: 8, borderRadius: '50%', background: '#6dd18e', boxShadow: '0 0 8px #6dd18e' }} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13, color: '#fff', fontWeight: 500, display: 'flex', alignItems: 'center', gap: 6 }}>
                  {r.n}
                  {r.batch && <span style={{ fontSize: 10, fontFamily: 'var(--font-mono)', color: '#7cc4ff', padding: '1px 6px', background: 'rgba(124, 196, 255, 0.15)', borderRadius: 4 }}>×{r.batch}</span>}
                </div>
                <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)', marginTop: 2 }}>{r.c}</div>
              </div>
              <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.4)', fontFamily: 'var(--font-mono)' }}>{r.t}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Big action */}
      <div style={{ position: 'absolute', bottom: 60, left: 16, right: 16, zIndex: 5 }}>
        <div style={{
          padding: '18px 22px', borderRadius: 22,
          background: 'linear-gradient(180deg, rgba(124, 196, 255, 0.9), rgba(124, 196, 255, 0.7))',
          boxShadow: '0 10px 30px rgba(124, 196, 255, 0.35), inset 0 1px 0 rgba(255,255,255,0.3)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
          color: '#0a1424', fontWeight: 600, fontSize: 16,
        }}>
          <div style={{ width: 20, height: 20 }}>{Icons.rfid}</div>
          Mantenha pressionado para escanear
        </div>
      </div>
    </IOSDevice>
  );
}

// ─────────────────────────────────────────────────────────
// V3 — AR / spatial view with RFID beam
// ─────────────────────────────────────────────────────────
function RfidScanV3() {
  return (
    <IOSDevice dark width={402} height={874}>
      {/* camera-like bg */}
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, oklch(0.18 0.04 250) 0%, oklch(0.10 0.02 250) 100%)' }}>
        {/* gridded floor */}
        <svg width="100%" height="100%" style={{ position: 'absolute', inset: 0, opacity: 0.25 }}>
          <defs>
            <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse" patternTransform="skewX(-10) skewY(5)">
              <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#7cc4ff" strokeWidth="0.5" />
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#grid)" />
        </svg>
      </div>

      {/* Beam cone from bottom */}
      <svg width="402" height="600" style={{ position: 'absolute', bottom: 100, left: 0, zIndex: 1, pointerEvents: 'none' }}>
        <defs>
          <linearGradient id="beam" x1="50%" y1="100%" x2="50%" y2="0%">
            <stop offset="0%" stopColor="rgba(124, 196, 255, 0.55)"/>
            <stop offset="100%" stopColor="rgba(124, 196, 255, 0)"/>
          </linearGradient>
        </defs>
        <polygon points="201,600 80,0 322,0" fill="url(#beam)" />
      </svg>

      {/* Detected item cards — floating in space */}
      {[
        { x: 80, y: 180, n: 'Par LED 18x10W', c: 'ILU-0042-012', d: '3.2m', fresh: true },
        { x: 230, y: 220, n: 'Moving Head', c: 'ILU-0088-008', d: '4.1m' },
        { x: 60, y: 320, n: 'Cabo XLR ×8', c: 'CAB-L012', d: '1.8m', batch: true },
        { x: 250, y: 380, n: 'Caixa JBL', c: 'AUD-0011-004', d: '2.5m' },
        { x: 150, y: 280, n: 'Subwoofer', c: 'AUD-0024', d: '3.8m' },
      ].map((t, i) => (
        <div key={i} style={{
          position: 'absolute', left: t.x, top: t.y, zIndex: 3,
          padding: '8px 10px', borderRadius: 14,
          background: t.fresh ? 'rgba(124, 196, 255, 0.25)' : 'rgba(255,255,255,0.08)',
          backdropFilter: 'blur(20px) saturate(180%)', WebkitBackdropFilter: 'blur(20px) saturate(180%)',
          border: t.fresh ? '1px solid rgba(124, 196, 255, 0.6)' : '1px solid rgba(255,255,255,0.15)',
          boxShadow: t.fresh ? '0 0 20px rgba(124, 196, 255, 0.4)' : '0 4px 12px rgba(0,0,0,0.3)',
          minWidth: 110,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <div style={{ width: 6, height: 6, borderRadius: '50%', background: t.fresh ? '#7cc4ff' : '#6dd18e', boxShadow: `0 0 6px ${t.fresh ? '#7cc4ff' : '#6dd18e'}` }} />
            <div style={{ fontSize: 11, color: '#fff', fontWeight: 500 }}>{t.n}</div>
            {t.batch && <span style={{ fontSize: 9, fontFamily: 'var(--font-mono)', color: '#b794ff' }}>LOTE</span>}
          </div>
          <div style={{ fontSize: 9, color: 'rgba(255,255,255,0.6)', fontFamily: 'var(--font-mono)', marginTop: 2, display: 'flex', gap: 6 }}>
            <span>{t.c}</span>
            <span>·</span>
            <span>{t.d}</span>
          </div>
        </div>
      ))}

      {/* Crosshair / reticle */}
      <div style={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)', pointerEvents: 'none' }}>
        <svg width="80" height="80" viewBox="0 0 80 80">
          <circle cx="40" cy="40" r="30" fill="none" stroke="rgba(124, 196, 255, 0.5)" strokeWidth="1" strokeDasharray="4 4"/>
          <circle cx="40" cy="40" r="3" fill="#7cc4ff"/>
        </svg>
      </div>

      {/* top hud */}
      <div style={{ position: 'absolute', top: 54, left: 16, right: 16, zIndex: 6, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{
          padding: '8px 12px', borderRadius: 14,
          background: 'rgba(0,0,0,0.5)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
          border: '1px solid rgba(255,255,255,0.15)', color: '#fff', fontSize: 12,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <StatusDot color="#6dd18e" size={6} />
            <span style={{ fontFamily: 'var(--font-mono)', fontSize: 10, color: 'rgba(255,255,255,0.7)', letterSpacing: 0.08 }}>ZEBRA RFD40</span>
            <span style={{ fontSize: 11, color: '#fff' }}>· 98%</span>
          </div>
        </div>
        <div style={{
          padding: '8px 14px', borderRadius: 14,
          background: 'rgba(124, 196, 255, 0.2)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
          border: '1px solid rgba(124, 196, 255, 0.4)', color: '#fff',
        }}>
          <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.6)', fontFamily: 'var(--font-mono)', letterSpacing: 0.08 }}>DETECTADOS</div>
          <div style={{ fontSize: 20, fontWeight: 500 }}>127<span style={{ fontSize: 11, color: 'rgba(255,255,255,0.5)' }}>/214</span></div>
        </div>
      </div>

      {/* bottom control */}
      <div style={{ position: 'absolute', bottom: 60, left: 0, right: 0, zIndex: 6, display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 20 }}>
        <div style={{
          width: 48, height: 48, borderRadius: 14,
          background: 'rgba(255,255,255,0.12)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
          border: '1px solid rgba(255,255,255,0.2)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff',
        }}>{Icons.qr}</div>
        <div style={{ position: 'relative', width: 84, height: 84 }}>
          <div style={{ position: 'absolute', inset: -10, borderRadius: '50%', background: 'radial-gradient(circle, rgba(124, 196, 255, 0.5), transparent 70%)', filter: 'blur(8px)' }} />
          <div style={{
            position: 'relative', width: 84, height: 84, borderRadius: '50%',
            background: 'linear-gradient(180deg, #fff, rgba(255,255,255,0.85))',
            boxShadow: 'inset 0 2px 0 rgba(255,255,255,1), 0 10px 30px rgba(0,0,0,0.4)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <div style={{ width: 68, height: 68, borderRadius: '50%', border: '3px solid #0a1424', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <div style={{ color: '#0a1424', width: 28, height: 28 }}>{Icons.rfid}</div>
            </div>
          </div>
        </div>
        <div style={{
          width: 48, height: 48, borderRadius: 14,
          background: 'rgba(255,255,255,0.12)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
          border: '1px solid rgba(255,255,255,0.2)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff',
        }}>{Icons.dot3}</div>
      </div>
    </IOSDevice>
  );
}

Object.assign(window, { RfidScanV1, RfidScanV2, RfidScanV3 });
