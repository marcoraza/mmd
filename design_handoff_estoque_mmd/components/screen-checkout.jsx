// screen-checkout.jsx — iOS Check-out Validation, 3 variations

// ─────────────────────────────────────────────────────────
// V1 — Scroll list with match/mismatch rows
// ─────────────────────────────────────────────────────────
function CheckoutV1() {
  return (
    <IOSDevice dark width={402} height={874}>
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(ellipse at top, oklch(0.18 0.04 250) 0%, oklch(0.08 0.02 250) 70%)' }} />

      {/* nav */}
      <div style={{ position: 'absolute', top: 54, left: 16, right: 16, display: 'flex', alignItems: 'center', gap: 10, zIndex: 6 }}>
        <IOSGlassPill dark><div style={{ padding: '0 12px', fontSize: 13, color: '#fff' }}>Voltar</div></IOSGlassPill>
        <div style={{ flex: 1, textAlign: 'center' }}>
          <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase' }}>Saída · packing</div>
          <div style={{ fontSize: 14, color: '#fff', fontWeight: 600 }}>Casamento Santos</div>
        </div>
        <IOSGlassPill dark><div style={{ padding: '0 12px', fontSize: 13, color: '#fff' }}>{Icons.dot3}</div></IOSGlassPill>
      </div>

      {/* Readiness header */}
      <div style={{ position: 'absolute', top: 120, left: 16, right: 16, padding: 20, borderRadius: 24,
        background: 'rgba(255,255,255,0.06)', backdropFilter: 'blur(30px) saturate(180%)', WebkitBackdropFilter: 'blur(30px) saturate(180%)',
        border: '1px solid rgba(255,255,255,0.12)', display: 'flex', alignItems: 'center', gap: 14 }}>
        <Ring value={87} size={72} stroke={6} />
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 13, color: '#fff', fontWeight: 500 }}>187 de 214 itens</div>
          <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.55)', marginTop: 2 }}>27 faltando · 0 fora da lista</div>
          <div style={{ marginTop: 8, height: 4, borderRadius: 2, background: 'rgba(255,255,255,0.1)', overflow: 'hidden' }}>
            <div style={{ width: '87%', height: '100%', background: 'linear-gradient(90deg, #6dd18e, #7cc4ff)' }} />
          </div>
        </div>
      </div>

      {/* Filter chips */}
      <div style={{ position: 'absolute', top: 248, left: 16, right: 16, display: 'flex', gap: 6, overflow: 'hidden' }}>
        {[
          { l: 'Faltando', c: '#ffb75c', n: 27, active: true },
          { l: 'Prontos', c: '#6dd18e', n: 187 },
          { l: 'Fora', c: 'rgba(255,255,255,0.4)', n: 0 },
        ].map((f, i) => (
          <div key={i} style={{
            padding: '6px 12px', borderRadius: 999, fontSize: 11, fontWeight: 500,
            background: f.active ? `color-mix(in oklch, ${f.c} 25%, transparent)` : 'rgba(255,255,255,0.06)',
            border: f.active ? `1px solid ${f.c}` : '1px solid rgba(255,255,255,0.1)',
            color: f.active ? f.c : 'rgba(255,255,255,0.7)',
            display: 'inline-flex', alignItems: 'center', gap: 6,
          }}>
            <StatusDot color={f.c} size={5} glow={false} />
            {f.l} <span style={{ fontFamily: 'var(--font-mono)', opacity: 0.7 }}>{f.n}</span>
          </div>
        ))}
      </div>

      {/* List */}
      <div style={{ position: 'absolute', top: 292, left: 16, right: 16, bottom: 170, borderRadius: 24,
        background: 'rgba(255,255,255,0.04)', backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
        border: '1px solid rgba(255,255,255,0.1)', overflow: 'hidden' }}>
        {[
          { n: 'Box Truss Q30 3m', c: 'MMD-EST-0009', status: 'missing', qty: 12 },
          { n: 'Moving Head Beam', c: 'MMD-ILU-0088', status: 'partial', alloc: 6, qty: 8 },
          { n: 'Cabo XLR 10m', c: 'MMD-CAB-L012', status: 'partial', alloc: 32, qty: 40 },
          { n: 'Par LED 18x10W', c: 'MMD-ILU-0042', status: 'ok', qty: 16 },
          { n: 'Mesa Yamaha QL5', c: 'MMD-AUD-0003', status: 'ok', qty: 1 },
          { n: 'Subwoofer JBL', c: 'MMD-AUD-0024', status: 'ok', qty: 4 },
        ].map((r, i) => {
          const sMap = {
            missing: { c: '#ff6b6b', label: `0/${r.qty}`, icon: Icons.x },
            partial: { c: '#ffb75c', label: `${r.alloc}/${r.qty}`, icon: Icons.warn },
            ok: { c: '#6dd18e', label: `${r.qty}/${r.qty}`, icon: Icons.check },
          };
          const s = sMap[r.status];
          return (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 16px', borderBottom: '0.5px solid rgba(255,255,255,0.06)' }}>
              <div style={{ width: 30, height: 30, borderRadius: 9, background: `color-mix(in oklch, ${s.c} 22%, transparent)`, border: `1px solid ${s.c}`, color: s.c, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{s.icon}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13, color: '#fff', fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.n}</div>
                <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)', marginTop: 2 }}>{r.c}</div>
              </div>
              <div style={{ fontSize: 13, color: s.c, fontFamily: 'var(--font-mono)', fontWeight: 600 }}>{s.label}</div>
            </div>
          );
        })}
      </div>

      {/* Action buttons */}
      <div style={{ position: 'absolute', bottom: 50, left: 16, right: 16, display: 'flex', gap: 8, zIndex: 6 }}>
        <div style={{
          flex: 1, padding: '14px', borderRadius: 18, textAlign: 'center',
          background: 'rgba(255,255,255,0.08)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
          border: '1px solid rgba(255,255,255,0.15)', color: '#fff', fontWeight: 500, fontSize: 14,
        }}>Continuar lendo</div>
        <div style={{
          flex: 1, padding: '14px', borderRadius: 18, textAlign: 'center',
          background: 'linear-gradient(180deg, rgba(124, 196, 255, 0.9), rgba(124, 196, 255, 0.7))',
          boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.3), 0 8px 20px rgba(124, 196, 255, 0.3)',
          color: '#0a1424', fontWeight: 600, fontSize: 14,
        }}>Confirmar saída</div>
      </div>
    </IOSDevice>
  );
}

// ─────────────────────────────────────────────────────────
// V2 — Visual grid: cell per item, color-coded
// ─────────────────────────────────────────────────────────
function CheckoutV2() {
  // 214 cells — sample: 187 ok, 27 missing, distributed
  const cells = [];
  for (let i = 0; i < 214; i++) {
    if ([3, 7, 18, 22, 31, 45, 56, 72, 89, 101, 118, 132, 145, 160, 172, 180, 194, 203, 8, 41, 68, 92, 128, 155, 177, 199, 210].includes(i)) {
      cells.push('missing');
    } else {
      cells.push('ok');
    }
  }

  return (
    <IOSDevice dark width={402} height={874}>
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, oklch(0.12 0.03 250), oklch(0.08 0.02 250))' }} />

      {/* top */}
      <div style={{ position: 'absolute', top: 54, left: 16, right: 16, display: 'flex', alignItems: 'center', zIndex: 6 }}>
        <IOSGlassPill dark><div style={{ padding: '0 12px', fontSize: 13, color: '#fff' }}>×</div></IOSGlassPill>
        <div style={{ flex: 1, textAlign: 'center', color: '#fff' }}>
          <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase' }}>Validação visual</div>
          <div style={{ fontSize: 14, fontWeight: 600 }}>Casamento Santos</div>
        </div>
        <IOSGlassPill dark><div style={{ padding: '0 12px', fontSize: 12, color: '#fff' }}>{Icons.qr}</div></IOSGlassPill>
      </div>

      {/* Big status */}
      <div style={{ position: 'absolute', top: 118, left: 0, right: 0, textAlign: 'center' }}>
        <div style={{ fontSize: 14, color: '#ffb75c', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase' }}>27 faltando</div>
        <div style={{ fontSize: 64, fontWeight: 300, color: '#fff', letterSpacing: -2, lineHeight: 1, marginTop: 4 }}>87<span style={{ fontSize: 32, color: 'rgba(255,255,255,0.4)' }}>%</span></div>
        <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)', marginTop: 4 }}>187 de 214 itens prontos</div>
      </div>

      {/* Grid - each square is one item */}
      <div style={{ position: 'absolute', top: 250, left: 20, right: 20, padding: 16, borderRadius: 22,
        background: 'rgba(255,255,255,0.04)', backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
        border: '1px solid rgba(255,255,255,0.1)' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
          <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.6)', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase' }}>214 unidades</div>
          <div style={{ display: 'flex', gap: 10, fontSize: 10, color: 'rgba(255,255,255,0.6)' }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}><span style={{ width: 8, height: 8, borderRadius: 2, background: '#6dd18e', boxShadow: '0 0 4px #6dd18e' }}/>OK</span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}><span style={{ width: 8, height: 8, borderRadius: 2, background: 'rgba(255,107,107,0.7)' }}/>Falta</span>
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(14, 1fr)', gap: 3 }}>
          {cells.map((c, i) => (
            <div key={i} style={{
              aspectRatio: 1, borderRadius: 3,
              background: c === 'ok' ? '#6dd18e' : 'rgba(255, 107, 107, 0.65)',
              boxShadow: c === 'ok' ? '0 0 4px rgba(109, 209, 142, 0.4)' : '0 0 8px rgba(255, 107, 107, 0.6)',
              opacity: c === 'ok' ? 0.75 : 1,
            }} />
          ))}
        </div>
      </div>

      {/* Missing callout */}
      <div style={{ position: 'absolute', bottom: 180, left: 16, right: 16, padding: 16, borderRadius: 20,
        background: 'rgba(255, 107, 107, 0.12)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
        border: '1px solid rgba(255, 107, 107, 0.35)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
          <div style={{ width: 28, height: 28, borderRadius: 8, background: 'rgba(255, 107, 107, 0.3)', color: '#ff6b6b', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{Icons.warn}</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 13, color: '#fff', fontWeight: 500 }}>27 itens faltando na leitura</div>
            <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.6)' }}>12 Box Truss · 8 Cabos XLR · 2 Moving · 5 outros</div>
          </div>
          <div style={{ fontSize: 11, color: '#7cc4ff' }}>Ver</div>
        </div>
      </div>

      {/* Button */}
      <div style={{ position: 'absolute', bottom: 50, left: 16, right: 16, zIndex: 6 }}>
        <div style={{
          padding: '16px', borderRadius: 22, textAlign: 'center',
          background: 'linear-gradient(180deg, #7cc4ff, #5a9fdb)',
          boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.3), 0 10px 24px rgba(124, 196, 255, 0.3)',
          color: '#0a1424', fontWeight: 600, fontSize: 15,
        }}>Continuar leitura RFID</div>
      </div>
    </IOSDevice>
  );
}

// ─────────────────────────────────────────────────────────
// V3 — Success state / ready to go
// ─────────────────────────────────────────────────────────
function CheckoutV3() {
  return (
    <IOSDevice dark width={402} height={874}>
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(ellipse at center, oklch(0.25 0.08 150) 0%, oklch(0.10 0.02 250) 70%)' }} />

      {/* Glow orbs */}
      <div style={{ position: 'absolute', top: 180, left: '50%', transform: 'translateX(-50%)', width: 300, height: 300, borderRadius: '50%',
        background: 'radial-gradient(circle, oklch(0.75 0.20 150 / 0.35), transparent 60%)', filter: 'blur(30px)' }} />

      {/* top */}
      <div style={{ position: 'absolute', top: 54, left: 16, right: 16, display: 'flex', alignItems: 'center', zIndex: 6 }}>
        <IOSGlassPill dark><div style={{ padding: '0 12px', fontSize: 13, color: '#fff' }}>×</div></IOSGlassPill>
        <div style={{ flex: 1 }} />
      </div>

      {/* Giant check */}
      <div style={{ position: 'absolute', top: 130, left: 0, right: 0, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <div style={{ position: 'relative', width: 200, height: 200 }}>
          {/* rings */}
          {[1, 0.75, 0.5].map((s, i) => (
            <div key={i} style={{
              position: 'absolute', inset: 0, margin: 'auto',
              width: 200 * s, height: 200 * s, borderRadius: '50%',
              border: '1px solid rgba(109, 209, 142, 0.3)',
              top: '50%', left: '50%', transform: `translate(-50%, -50%)`,
            }} />
          ))}
          {/* check bubble */}
          <div style={{
            position: 'absolute', inset: 0, margin: 'auto', width: 120, height: 120, borderRadius: '50%',
            background: 'linear-gradient(180deg, oklch(0.80 0.20 150), oklch(0.60 0.22 150))',
            boxShadow: '0 0 60px oklch(0.75 0.20 150 / 0.6), inset 0 2px 0 rgba(255,255,255,0.3)',
            top: '50%', left: '50%', transform: 'translate(-50%, -50%)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="56" height="56" viewBox="0 0 56 56" fill="none">
              <path d="M14 28L24 38L42 18" stroke="#fff" strokeWidth="4.5" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </div>
        </div>

        <div style={{ marginTop: 36, textAlign: 'center' }}>
          <div style={{ fontSize: 32, fontWeight: 500, color: '#fff', letterSpacing: -0.8 }}>Tudo certo</div>
          <div style={{ fontSize: 14, color: 'rgba(255,255,255,0.65)', marginTop: 8, maxWidth: 280 }}>
            Os 214 itens do Casamento Santos & Oliveira foram validados e marcados como EM_CAMPO.
          </div>
        </div>
      </div>

      {/* Summary card */}
      <div style={{ position: 'absolute', bottom: 180, left: 16, right: 16, padding: 18, borderRadius: 22,
        background: 'rgba(255,255,255,0.06)', backdropFilter: 'blur(30px) saturate(180%)', WebkitBackdropFilter: 'blur(30px) saturate(180%)',
        border: '1px solid rgba(255,255,255,0.12)' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
          {[
            { l: 'Lidos', v: '214', c: '#fff' },
            { l: 'Método', v: 'RFID', c: '#7cc4ff' },
            { l: 'Tempo', v: '2m 14s', c: 'rgba(255,255,255,0.8)' },
          ].map((s, i) => (
            <div key={i} style={{ textAlign: 'center' }}>
              <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)', letterSpacing: 0.08, textTransform: 'uppercase' }}>{s.l}</div>
              <div style={{ fontSize: 18, color: s.c, fontWeight: 500, marginTop: 4 }}>{s.v}</div>
            </div>
          ))}
        </div>
        <div style={{ borderTop: '1px solid rgba(255,255,255,0.08)', marginTop: 14, paddingTop: 12 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 11, color: 'rgba(255,255,255,0.55)' }}>
            <StatusDot color="#6dd18e" size={5} />
            <span>Carreta 01 · Gabriel · 18:32</span>
          </div>
        </div>
      </div>

      {/* actions */}
      <div style={{ position: 'absolute', bottom: 50, left: 16, right: 16, display: 'flex', gap: 8, zIndex: 6 }}>
        <div style={{
          flex: 1, padding: '14px', borderRadius: 18, textAlign: 'center',
          background: 'rgba(255,255,255,0.08)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
          border: '1px solid rgba(255,255,255,0.15)', color: '#fff', fontWeight: 500, fontSize: 14,
        }}>Resumo PDF</div>
        <div style={{
          flex: 1.4, padding: '14px', borderRadius: 18, textAlign: 'center',
          background: 'linear-gradient(180deg, #fff, rgba(255,255,255,0.92))',
          color: '#0a1424', fontWeight: 600, fontSize: 14,
        }}>Próximo evento →</div>
      </div>
    </IOSDevice>
  );
}

Object.assign(window, { CheckoutV1, CheckoutV2, CheckoutV3 });
