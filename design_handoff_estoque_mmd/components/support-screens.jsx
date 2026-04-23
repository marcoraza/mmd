// support-screens.jsx. QR sheet, Tag binding, Item lost, Onboarding, Packing

// ═══════════════════════════════════════════════════════════
// 01 — QR Print Sheet (web, print-optimized)
// ═══════════════════════════════════════════════════════════
function QRPrintSheet() {
  const items = [
    { code: 'MMD-ILU-0042', name: 'Par LED 18x10W', cat: 'Iluminação', batch: 'L-2024-11' },
    { code: 'MMD-ILU-0043', name: 'Par LED 18x10W', cat: 'Iluminação', batch: 'L-2024-11' },
    { code: 'MMD-ILU-0044', name: 'Par LED 18x10W', cat: 'Iluminação', batch: 'L-2024-11' },
    { code: 'MMD-AUD-0088', name: 'Caixa JBL VRX932', cat: 'Áudio', batch: 'L-2024-11' },
    { code: 'MMD-AUD-0089', name: 'Caixa JBL VRX932', cat: 'Áudio', batch: 'L-2024-11' },
    { code: 'MMD-AUD-0090', name: 'Caixa JBL VRX932', cat: 'Áudio', batch: 'L-2024-11' },
    { code: 'MMD-CAB-0201', name: 'Cabo XLR 10m', cat: 'Cabo', batch: 'L-2024-11' },
    { code: 'MMD-CAB-0202', name: 'Cabo XLR 10m', cat: 'Cabo', batch: 'L-2024-11' },
    { code: 'MMD-CAB-0203', name: 'Cabo XLR 10m', cat: 'Cabo', batch: 'L-2024-11' },
    { code: 'MMD-EST-0015', name: 'Box Truss Q30 3m', cat: 'Estrutura', batch: 'L-2024-11' },
    { code: 'MMD-EST-0016', name: 'Box Truss Q30 3m', cat: 'Estrutura', batch: 'L-2024-11' },
    { code: 'MMD-EST-0017', name: 'Box Truss Q30 3m', cat: 'Estrutura', batch: 'L-2024-11' },
  ];

  return (
    <div style={{ width: 1280, height: 820, position: 'relative', background: 'var(--bg-0)', display: 'flex' }}>
      <Caustic />
      <SideRail active="inventory" />

      <div style={{ flex: 1, padding: '28px 32px', position: 'relative', zIndex: 2, display: 'flex', gap: 24 }}>
        {/* Config panel */}
        <div style={{ width: 320, display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div>
            <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', letterSpacing: 0.08, textTransform: 'uppercase', marginBottom: 6 }}>Inventário · impressão</div>
            <h1 style={{ margin: 0, fontSize: 26, fontWeight: 500, letterSpacing: -0.4, color: 'var(--fg-0)' }}>QR em lote</h1>
            <p style={{ fontSize: 13, color: 'var(--fg-2)', margin: '6px 0 0', lineHeight: 1.5 }}>12 itens selecionados · papel A4 · 12 QRs / folha</p>
          </div>

          <GlassCard style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
            <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', letterSpacing: 0.08, textTransform: 'uppercase' }}>Layout</div>
            {[
              { label: '3×4 (grande)', active: true, sub: '12/folha · 65×65mm' },
              { label: '4×6 (médio)', active: false, sub: '24/folha · 45×45mm' },
              { label: '6×10 (pequeno)', active: false, sub: '60/folha · 25×25mm' },
            ].map(l => (
              <div key={l.label} style={{
                padding: '10px 12px', borderRadius: 10,
                background: l.active ? 'var(--accent-cyan-soft)' : 'var(--glass-bg)',
                border: `1px solid ${l.active ? 'var(--accent-cyan)' : 'var(--glass-border)'}`,
                cursor: 'pointer',
              }}>
                <div style={{ fontSize: 13, color: l.active ? 'var(--accent-cyan)' : 'var(--fg-0)', fontWeight: 500 }}>{l.label}</div>
                <div style={{ fontSize: 11, color: 'var(--fg-3)', marginTop: 2 }}>{l.sub}</div>
              </div>
            ))}
          </GlassCard>

          <GlassCard style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', letterSpacing: 0.08, textTransform: 'uppercase' }}>Conteúdo da etiqueta</div>
            {[
              ['QR code', true], ['Código MMD', true], ['Nome do item', true], ['Categoria', true], ['Lote', false], ['Logo MMD', true],
            ].map(([lbl, on]) => (
              <div key={lbl} style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 13, color: 'var(--fg-1)' }}>
                <div style={{ width: 16, height: 16, borderRadius: 4, background: on ? 'var(--accent-cyan)' : 'transparent', border: `1px solid ${on ? 'var(--accent-cyan)' : 'var(--glass-border-strong)'}`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#000' }}>{on && Icons.check}</div>
                {lbl}
              </div>
            ))}
          </GlassCard>

          <div style={{ display: 'flex', gap: 8, marginTop: 'auto' }}>
            <GhostBtn style={{ flex: 1 }}>{Icons.arrow} Voltar</GhostBtn>
            <PrimaryBtn style={{ flex: 1.5 }}>Imprimir · 1 folha</PrimaryBtn>
          </div>
        </div>

        {/* Print preview — a realistic A4 sheet */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 12, alignItems: 'center' }}>
          <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', letterSpacing: 0.08, textTransform: 'uppercase', alignSelf: 'flex-start' }}>Preview · A4 retrato</div>
          <div style={{
            width: 520, height: 720, background: '#fff', borderRadius: 4,
            boxShadow: '0 30px 80px rgba(0,0,0,0.5)',
            display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gridTemplateRows: 'repeat(4, 1fr)',
            gap: 8, padding: 32, position: 'relative',
          }}>
            {items.map((it, i) => (
              <div key={it.code} style={{
                border: '1px dashed rgba(0,0,0,0.15)', borderRadius: 6,
                padding: 8, display: 'flex', flexDirection: 'column',
                fontFamily: 'var(--font-mono)', fontSize: 7, color: '#000',
                background: '#fff',
              }}>
                <div style={{ display: 'flex', gap: 6 }}>
                  {/* Stylized QR */}
                  <div style={{ width: 56, height: 56, background: '#000', position: 'relative', flexShrink: 0 }}>
                    <div style={{ position: 'absolute', inset: 3, background: `
                      radial-gradient(circle at 10% 10%, #fff 4%, transparent 5%),
                      radial-gradient(circle at 90% 10%, #fff 4%, transparent 5%),
                      radial-gradient(circle at 10% 90%, #fff 4%, transparent 5%),
                      repeating-conic-gradient(#000 0% 25%, #fff 0% 50%)
                    `, backgroundSize: '100%, 100%, 100%, 10px 10px' }} />
                    <div style={{ position: 'absolute', top: 3, left: 3, width: 12, height: 12, background: '#000', border: '2px solid #fff', boxShadow: 'inset 0 0 0 1px #000' }} />
                    <div style={{ position: 'absolute', top: 3, right: 3, width: 12, height: 12, background: '#000', border: '2px solid #fff', boxShadow: 'inset 0 0 0 1px #000' }} />
                    <div style={{ position: 'absolute', bottom: 3, left: 3, width: 12, height: 12, background: '#000', border: '2px solid #fff', boxShadow: 'inset 0 0 0 1px #000' }} />
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 8, fontWeight: 700, letterSpacing: 0.5 }}>{it.code}</div>
                    <div style={{ fontSize: 7, fontFamily: 'Inter Tight', marginTop: 2, color: '#333', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{it.name}</div>
                    <div style={{ fontSize: 6, color: '#666', marginTop: 1 }}>{it.cat}</div>
                  </div>
                </div>
                <div style={{ marginTop: 'auto', paddingTop: 4, borderTop: '1px solid #eee', display: 'flex', justifyContent: 'space-between', color: '#999', fontSize: 6 }}>
                  <span>MMD</span><span>{it.batch}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 02 — Vinculação tag RFID ↔ serial (iOS)
// ═══════════════════════════════════════════════════════════
function TagBind() {
  return (
    <IOSDevice dark width={402} height={874}>
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, oklch(0.14 0.04 250), oklch(0.08 0.02 250))' }} />
      <div style={{ position: 'absolute', top: '20%', left: '50%', width: 500, height: 500, transform: 'translate(-50%, -50%)', background: 'radial-gradient(circle, oklch(0.72 0.20 295) 0%, transparent 60%)', filter: 'blur(60px)', opacity: 0.5, mixBlendMode: 'screen' }} />

      <div style={{ position: 'absolute', top: 54, left: 16, right: 16, display: 'flex', alignItems: 'center', gap: 10 }}>
        <IOSGlassPill dark><div style={{ padding: '0 12px', fontSize: 13, color: '#fff' }}>Cancelar</div></IOSGlassPill>
        <div style={{ flex: 1, textAlign: 'center' }}>
          <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase' }}>Passo 2 de 2</div>
          <div style={{ fontSize: 14, color: '#fff', fontWeight: 600 }}>Vincular tag</div>
        </div>
        <div style={{ width: 44 }} />
      </div>

      {/* Serial card — top */}
      <div style={{ position: 'absolute', top: 120, left: 16, right: 16, padding: 16, borderRadius: 20,
        background: 'rgba(255,255,255,0.06)', backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
        border: '1px solid rgba(255,255,255,0.12)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 56, height: 56, borderRadius: 12, background: 'repeating-linear-gradient(45deg, rgba(255,255,255,0.06), rgba(255,255,255,0.06) 6px, rgba(255,255,255,0.12) 6px, rgba(255,255,255,0.12) 12px)', border: '1px dashed rgba(255,255,255,0.2)' }} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase' }}>Serial MMD</div>
            <div style={{ fontSize: 15, color: '#fff', fontWeight: 600, marginTop: 2 }}>Moving Head Beam 230W</div>
            <div style={{ fontSize: 11, color: '#7cc4ff', fontFamily: 'var(--font-mono)', marginTop: 2 }}>MMD-ILU-0088</div>
          </div>
          <div style={{ color: '#6dd18e' }}>{Icons.check}</div>
        </div>
      </div>

      {/* Connector */}
      <div style={{ position: 'absolute', left: '50%', top: 230, transform: 'translateX(-50%)', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
        <div style={{ width: 2, height: 18, background: 'linear-gradient(180deg, #7cc4ff, transparent)' }} />
        <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)', letterSpacing: 0.15, textTransform: 'uppercase' }}>↕ vincular</div>
        <div style={{ width: 2, height: 18, background: 'linear-gradient(0deg, oklch(0.70 0.17 295), transparent)' }} />
      </div>

      {/* Tag scan ring — hero area */}
      <div style={{ position: 'absolute', left: '50%', top: 320, transform: 'translateX(-50%)', width: 220, height: 220 }}>
        {[0,1,2].map(i => (
          <div key={i} style={{
            position: 'absolute', inset: i*14, borderRadius: '50%',
            border: `1px solid rgba(124, 196, 255, ${0.4 - i*0.1})`,
            animation: `scanPulse 2s ${i*0.3}s ease-out infinite`,
          }} />
        ))}
        <div style={{ position: 'absolute', inset: 52, borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(124, 196, 255, 0.3), rgba(124, 196, 255, 0.08) 70%)',
          border: '1.5px solid rgba(124, 196, 255, 0.6)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column',
        }}>
          <div style={{ color: '#7cc4ff', transform: 'scale(2.2)', marginBottom: 10 }}>{Icons.rfid}</div>
          <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.7)', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase' }}>aproxime a tag</div>
        </div>
      </div>

      {/* Tag detected card */}
      <div style={{ position: 'absolute', top: 570, left: 16, right: 16, padding: 14, borderRadius: 16,
        background: 'rgba(124, 196, 255, 0.08)', backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
        border: '1px solid rgba(124, 196, 255, 0.3)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 32, height: 32, borderRadius: 8, background: 'rgba(124, 196, 255, 0.25)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#7cc4ff' }}>{Icons.rfid}</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase' }}>Tag detectada</div>
            <div style={{ fontSize: 12, color: '#fff', fontFamily: 'var(--font-mono)', marginTop: 2 }}>E2-00-68-94-0B-2C-7F-AE</div>
          </div>
          <StatusDot color="#6dd18e" size={8} />
        </div>
        <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.5)', marginTop: 8, lineHeight: 1.4 }}>
          EPC Gen 2 · sinal -42 dBm · livre pra vincular
        </div>
      </div>

      {/* CTA */}
      <div style={{ position: 'absolute', bottom: 50, left: 16, right: 16, display: 'flex', gap: 8 }}>
        <div style={{ flex: 1, padding: '13px', borderRadius: 18, textAlign: 'center', background: 'rgba(255,255,255,0.08)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)', border: '1px solid rgba(255,255,255,0.15)', color: '#fff', fontWeight: 500, fontSize: 13 }}>Ler outra</div>
        <div style={{ flex: 1.5, padding: '13px', borderRadius: 18, textAlign: 'center', background: 'linear-gradient(180deg, rgba(124, 196, 255, 0.95), rgba(124, 196, 255, 0.75))', boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.3), 0 8px 20px rgba(124, 196, 255, 0.3)', color: '#0a1424', fontWeight: 600, fontSize: 13 }}>Confirmar vínculo</div>
      </div>

      <style>{`
        @keyframes scanPulse {
          0% { opacity: 0.8; transform: scale(0.7); }
          100% { opacity: 0; transform: scale(1.15); }
        }
      `}</style>
    </IOSDevice>
  );
}

// ═══════════════════════════════════════════════════════════
// 03 — Item perdido / busca (iOS)
// ═══════════════════════════════════════════════════════════
function ItemLost() {
  return (
    <IOSDevice dark width={402} height={874}>
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, oklch(0.14 0.04 20), oklch(0.08 0.02 250))' }} />
      <div style={{ position: 'absolute', top: '10%', left: '50%', width: 500, height: 500, transform: 'translate(-50%, -50%)', background: 'radial-gradient(circle, oklch(0.70 0.18 25) 0%, transparent 60%)', filter: 'blur(60px)', opacity: 0.35, mixBlendMode: 'screen' }} />

      <div style={{ position: 'absolute', top: 54, left: 16, right: 16, display: 'flex', alignItems: 'center', gap: 10 }}>
        <IOSGlassPill dark><div style={{ padding: '0 12px', fontSize: 13, color: '#fff' }}>Voltar</div></IOSGlassPill>
        <div style={{ flex: 1 }} />
        <IOSGlassPill dark><div style={{ padding: '0 12px', fontSize: 13, color: '#fff' }}>{Icons.dot3}</div></IOSGlassPill>
      </div>

      {/* Item header */}
      <div style={{ position: 'absolute', top: 118, left: 16, right: 16 }}>
        <div style={{ fontSize: 10, color: '#ff6b6b', fontFamily: 'var(--font-mono)', letterSpacing: 0.12, textTransform: 'uppercase', marginBottom: 4 }}>⚠ Item não encontrado</div>
        <div style={{ fontSize: 22, color: '#fff', fontWeight: 500, letterSpacing: -0.3 }}>Moving Head Beam 230W</div>
        <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)', marginTop: 2 }}>MMD-ILU-0088 · esperado no Casamento Santos</div>
      </div>

      {/* Last seen */}
      <div style={{ position: 'absolute', top: 210, left: 16, right: 16, padding: 16, borderRadius: 18,
        background: 'rgba(255,255,255,0.05)', backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
        border: '1px solid rgba(255,255,255,0.1)' }}>
        <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase' }}>Última leitura</div>
        <div style={{ fontSize: 15, color: '#fff', marginTop: 6, fontWeight: 500 }}>Galpão A · Prateleira 12</div>
        <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.6)', marginTop: 4 }}>há 6 dias · check-in do Réveillon Copacabana</div>
        <div style={{ display: 'flex', gap: 6, marginTop: 12 }}>
          <div style={{ padding: '6px 10px', borderRadius: 8, background: 'rgba(255,255,255,0.08)', fontSize: 11, color: '#fff' }}>Ver no mapa</div>
          <div style={{ padding: '6px 10px', borderRadius: 8, background: 'rgba(255,255,255,0.08)', fontSize: 11, color: '#fff' }}>Histórico</div>
        </div>
      </div>

      {/* RFID beacon search — hero */}
      <div style={{ position: 'absolute', top: 346, left: 16, right: 16, padding: 20, borderRadius: 22,
        background: 'rgba(255, 107, 107, 0.08)', backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
        border: '1px solid rgba(255, 107, 107, 0.3)', textAlign: 'center' }}>
        <div style={{ fontSize: 10, color: '#ff6b6b', fontFamily: 'var(--font-mono)', letterSpacing: 0.12, textTransform: 'uppercase' }}>Busca ativa · RFID</div>
        <div style={{ fontSize: 17, color: '#fff', fontWeight: 500, marginTop: 6 }}>Procurando a tag pelo prédio</div>

        {/* Signal strength meter */}
        <div style={{ marginTop: 18, marginBottom: 14, position: 'relative', height: 80 }}>
          <svg width="100%" height="80" viewBox="0 0 300 80">
            {[...Array(20)].map((_, i) => {
              const strength = Math.max(0, 0.3 + Math.sin(i * 0.35) * 0.5);
              const height = 8 + strength * 60;
              return <rect key={i} x={i*15+3} y={80-height} width={10} height={height} rx={2} fill={`rgba(255, 107, 107, ${0.3 + strength * 0.5})`} />;
            })}
          </svg>
          <div style={{ position: 'absolute', right: 8, top: 0, fontSize: 11, color: '#ff6b6b', fontFamily: 'var(--font-mono)' }}>-68 dBm</div>
        </div>

        <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.7)', marginBottom: 4 }}>Sinal fraco · ande pelo galpão</div>
        <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.5)' }}>Fica mais forte quando você se aproxima</div>
      </div>

      {/* Actions */}
      <div style={{ position: 'absolute', bottom: 110, left: 16, right: 16, display: 'flex', flexDirection: 'column', gap: 8 }}>
        <div style={{ padding: 14, borderRadius: 14, background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ color: 'rgba(255,255,255,0.6)' }}>{Icons.warn}</div>
          <div style={{ flex: 1, fontSize: 12, color: '#fff' }}>Marcar como perdido definitivamente</div>
          <div style={{ color: 'rgba(255,255,255,0.4)' }}>{Icons.chevron}</div>
        </div>
        <div style={{ padding: 14, borderRadius: 14, background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ color: 'rgba(255,255,255,0.6)' }}>{Icons.package}</div>
          <div style={{ flex: 1, fontSize: 12, color: '#fff' }}>Substituir pelo unit #0089</div>
          <div style={{ color: 'rgba(255,255,255,0.4)' }}>{Icons.chevron}</div>
        </div>
      </div>

      <div style={{ position: 'absolute', bottom: 50, left: 16, right: 16 }}>
        <div style={{ padding: '13px', borderRadius: 18, textAlign: 'center', background: 'linear-gradient(180deg, rgba(255, 107, 107, 0.95), rgba(255, 107, 107, 0.75))', boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.3), 0 8px 20px rgba(255, 107, 107, 0.3)', color: '#fff', fontWeight: 600, fontSize: 13 }}>Iniciar busca no galpão</div>
      </div>
    </IOSDevice>
  );
}

// ═══════════════════════════════════════════════════════════
// 04 — Onboarding primeiro scan (iOS)
// ═══════════════════════════════════════════════════════════
function Onboarding() {
  return (
    <IOSDevice dark width={402} height={874}>
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(ellipse at top, oklch(0.20 0.08 260), oklch(0.06 0.02 250) 70%)' }} />
      <div style={{ position: 'absolute', top: '30%', left: '50%', width: 600, height: 600, transform: 'translate(-50%, -50%)', background: 'conic-gradient(from 0deg, oklch(0.72 0.18 210), oklch(0.72 0.20 295), oklch(0.80 0.15 150), oklch(0.72 0.18 210))', filter: 'blur(80px)', opacity: 0.4, mixBlendMode: 'screen', borderRadius: '50%' }} />

      {/* Hero illustration area */}
      <div style={{ position: 'absolute', top: 120, left: 0, right: 0, height: 360, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ position: 'relative', width: 220, height: 220 }}>
          {/* Phone + RFID gun illustration */}
          <div style={{ position: 'absolute', inset: 0, borderRadius: '50%', background: 'radial-gradient(circle, rgba(124,196,255,0.25), transparent 70%)' }} />
          {[0,1,2,3].map(i => (
            <div key={i} style={{
              position: 'absolute', left: '50%', top: '50%', width: 4, height: 4, borderRadius: '50%',
              background: ['#7cc4ff', '#b39cff', '#6dd18e', '#ffb75c'][i],
              boxShadow: `0 0 20px ${['#7cc4ff', '#b39cff', '#6dd18e', '#ffb75c'][i]}`,
              transform: `translate(-50%, -50%) rotate(${i*90}deg) translateY(-80px)`,
            }} />
          ))}
          <div style={{ position: 'absolute', inset: 70, borderRadius: 20, background: 'rgba(255,255,255,0.06)', backdropFilter: 'blur(30px)', border: '1px solid rgba(255,255,255,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <div style={{ color: '#7cc4ff', transform: 'scale(2.5)' }}>{Icons.rfid}</div>
          </div>
        </div>
      </div>

      {/* Text */}
      <div style={{ position: 'absolute', bottom: 220, left: 28, right: 28, textAlign: 'center' }}>
        <div style={{ fontSize: 10, color: '#7cc4ff', fontFamily: 'var(--font-mono)', letterSpacing: 0.15, textTransform: 'uppercase' }}>Primeiro scan · passo 1 de 3</div>
        <h1 style={{ fontSize: 28, color: '#fff', fontWeight: 500, letterSpacing: -0.5, margin: '14px 0 12px', lineHeight: 1.15 }}>Segure o leitor.<br/>Puxe o gatilho.</h1>
        <p style={{ fontSize: 14, color: 'rgba(255,255,255,0.65)', lineHeight: 1.5, margin: 0 }}>
          Cada tag lida vira uma partícula brilhante na tela. Não precisa mirar — o RFID vê tudo num raio de 3 metros.
        </p>
      </div>

      {/* Progress dots */}
      <div style={{ position: 'absolute', bottom: 130, left: 0, right: 0, display: 'flex', justifyContent: 'center', gap: 8 }}>
        <div style={{ width: 24, height: 6, borderRadius: 3, background: '#7cc4ff' }} />
        <div style={{ width: 6, height: 6, borderRadius: 3, background: 'rgba(255,255,255,0.2)' }} />
        <div style={{ width: 6, height: 6, borderRadius: 3, background: 'rgba(255,255,255,0.2)' }} />
      </div>

      {/* CTA */}
      <div style={{ position: 'absolute', bottom: 50, left: 28, right: 28, display: 'flex', gap: 8 }}>
        <div style={{ flex: 1, padding: '14px', borderRadius: 18, textAlign: 'center', background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.7)', fontSize: 13 }}>Pular</div>
        <div style={{ flex: 2, padding: '14px', borderRadius: 18, textAlign: 'center', background: 'linear-gradient(180deg, rgba(124, 196, 255, 0.95), rgba(124, 196, 255, 0.75))', boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.3), 0 8px 20px rgba(124, 196, 255, 0.3)', color: '#0a1424', fontWeight: 600, fontSize: 14 }}>Próximo</div>
      </div>
    </IOSDevice>
  );
}

// ═══════════════════════════════════════════════════════════
// 05a — Packing mode (iOS) — espelho do checkout com camada de sugestão
// ═══════════════════════════════════════════════════════════
function PackingMirror() {
  const [scanned, setScanned] = React.useState(87);
  const rows = [
    { n: 'Par LED 18x10W', c: 'MMD-ILU-0042', status: 'partial', qty: 16, alloc: 12, sug: 'Prateleira A3' },
    { n: 'Moving Head Beam 230W', c: 'MMD-ILU-0088', status: 'partial', qty: 8, alloc: 5, sug: 'Prateleira B1' },
    { n: 'Box Truss Q30 3m', c: 'MMD-EST-0015', status: 'pending', qty: 12, alloc: 0, sug: 'Área externa · setor 3' },
    { n: 'Cabo XLR 10m', c: 'MMD-CAB-L012', status: 'done', qty: 40, alloc: 40, sug: null },
    { n: 'Mesa Yamaha QL5', c: 'MMD-AUD-0003', status: 'done', qty: 1, alloc: 1, sug: null },
    { n: 'Subwoofer JBL SRX818', c: 'MMD-AUD-0024', status: 'pending', qty: 4, alloc: 0, sug: 'Prateleira B4' },
  ];

  return (
    <IOSDevice dark width={402} height={874}>
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, oklch(0.14 0.04 250), oklch(0.08 0.02 250))' }} />

      <div style={{ position: 'absolute', top: 54, left: 16, right: 16, display: 'flex', alignItems: 'center', gap: 10 }}>
        <IOSGlassPill dark><div style={{ padding: '0 12px', fontSize: 13, color: '#fff' }}>Voltar</div></IOSGlassPill>
        <div style={{ flex: 1, textAlign: 'center' }}>
          <div style={{ fontSize: 10, color: '#b39cff', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase' }}>Empacotamento · +rota</div>
          <div style={{ fontSize: 14, color: '#fff', fontWeight: 600 }}>Casamento Santos</div>
        </div>
        <IOSGlassPill dark><div style={{ padding: '0 12px', fontSize: 13, color: '#fff' }}>{Icons.qr}</div></IOSGlassPill>
      </div>

      {/* Readiness + counter */}
      <div style={{ position: 'absolute', top: 115, left: 16, right: 16, display: 'flex', alignItems: 'center', gap: 16 }}>
        <Ring value={41} size={72} stroke={6} />
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 28, fontWeight: 500, color: '#fff', letterSpacing: -0.6, lineHeight: 1 }}>{scanned}<span style={{ color: 'rgba(255,255,255,0.4)', fontSize: 16 }}>/214</span></div>
          <div style={{ fontSize: 12, color: '#b39cff', marginTop: 4, fontWeight: 500 }}>Próximo sugerido: Prateleira A3</div>
          <div style={{ marginTop: 6, height: 3, borderRadius: 2, background: 'rgba(255,255,255,0.1)', overflow: 'hidden' }}>
            <div style={{ width: '41%', height: '100%', background: 'linear-gradient(90deg, #b39cff, #7cc4ff)' }} />
          </div>
        </div>
      </div>

      {/* Suggestion banner — hero layer */}
      <div style={{ position: 'absolute', top: 220, left: 16, right: 16, padding: 14, borderRadius: 18,
        background: 'linear-gradient(135deg, rgba(179, 156, 255, 0.12), rgba(124, 196, 255, 0.08))',
        backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
        border: '1px solid rgba(179, 156, 255, 0.3)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
          <div style={{ width: 28, height: 28, borderRadius: 8, background: 'rgba(179, 156, 255, 0.25)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#b39cff' }}>{Icons.zap}</div>
          <div style={{ fontSize: 10, color: '#b39cff', fontFamily: 'var(--font-mono)', letterSpacing: 0.12, textTransform: 'uppercase' }}>Rota otimizada</div>
        </div>
        <div style={{ fontSize: 13, color: '#fff', lineHeight: 1.5 }}>
          Comece pela <b>Prateleira A3</b> (Par LED · 4 faltando), depois <b>B1</b> (Moving Head · 3). Economiza ~7 min vs ordem aleatória.
        </div>
      </div>

      {/* List */}
      <div style={{ position: 'absolute', top: 350, left: 16, right: 16, bottom: 120, borderRadius: 22, overflow: 'hidden',
        background: 'rgba(255,255,255,0.04)', backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
        border: '1px solid rgba(255,255,255,0.1)' }}>
        <div style={{ padding: '10px 14px', borderBottom: '1px solid rgba(255,255,255,0.08)', display: 'flex', alignItems: 'center' }}>
          <span style={{ fontSize: 12, color: '#fff', fontWeight: 500 }}>Itens a embalar</span>
          <div style={{ flex: 1 }} />
          <span style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)' }}>por rota ↓</span>
        </div>
        <div style={{ overflow: 'auto', maxHeight: '100%' }}>
          {rows.map((r, i) => {
            const sMap = {
              pending: { c: '#b39cff', label: `0/${r.qty}`, icon: Icons.package, ring: false },
              partial: { c: '#ffb75c', label: `${r.alloc}/${r.qty}`, icon: Icons.zap, ring: true },
              done:    { c: '#6dd18e', label: `${r.qty}/${r.qty}`, icon: Icons.check, ring: false },
            };
            const s = sMap[r.status];
            return (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '11px 14px', borderBottom: '0.5px solid rgba(255,255,255,0.06)',
                background: s.ring ? 'rgba(179, 156, 255, 0.06)' : 'transparent' }}>
                <div style={{ width: 28, height: 28, borderRadius: 8, background: `color-mix(in oklch, ${s.c} 22%, transparent)`, border: `1px solid ${s.c}`, color: s.c, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{s.icon}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 12, color: '#fff', fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.n}</div>
                  <div style={{ fontSize: 9, color: r.sug ? '#b39cff' : 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)', marginTop: 2 }}>
                    {r.sug ? `→ ${r.sug}` : r.c}
                  </div>
                </div>
                <div style={{ fontSize: 12, color: s.c, fontFamily: 'var(--font-mono)', fontWeight: 600 }}>{s.label}</div>
              </div>
            );
          })}
        </div>
      </div>

      {/* CTA */}
      <div style={{ position: 'absolute', bottom: 50, left: 16, right: 16, display: 'flex', gap: 8 }}>
        <div style={{ flex: 1, padding: '13px', borderRadius: 18, textAlign: 'center', background: 'rgba(255,255,255,0.08)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)', border: '1px solid rgba(255,255,255,0.15)', color: '#fff', fontWeight: 500, fontSize: 13 }}>Continuar</div>
        <div style={{ flex: 1.2, padding: '13px', borderRadius: 18, textAlign: 'center', background: 'linear-gradient(180deg, rgba(179, 156, 255, 0.95), rgba(179, 156, 255, 0.75))', boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.3), 0 8px 20px rgba(179, 156, 255, 0.3)', color: '#1a0f2e', fontWeight: 600, fontSize: 13 }}>Finalizar packing</div>
      </div>
    </IOSDevice>
  );
}

// ═══════════════════════════════════════════════════════════
// 05b — Packing mode · map-first (iOS) — variação
// ═══════════════════════════════════════════════════════════
function PackingMap() {
  const shelves = [
    { id: 'A1', x: 20, y: 30, pending: 0, total: 12, done: true },
    { id: 'A2', x: 95, y: 30, pending: 0, total: 8, done: true },
    { id: 'A3', x: 170, y: 30, pending: 4, total: 16, active: true },
    { id: 'A4', x: 245, y: 30, pending: 0, total: 4, done: true },
    { id: 'B1', x: 20, y: 120, pending: 3, total: 8, pending2: true },
    { id: 'B2', x: 95, y: 120, pending: 0, total: 2, done: true },
    { id: 'B3', x: 170, y: 120, pending: 0, total: 30, done: true },
    { id: 'B4', x: 245, y: 120, pending: 4, total: 4, pending2: true },
    { id: 'C1', x: 20, y: 210, pending: 0, total: 1, done: true },
    { id: 'EXT', x: 95, y: 210, pending: 12, total: 12, pending3: true, wide: true },
  ];

  return (
    <IOSDevice dark width={402} height={874}>
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, oklch(0.14 0.04 250), oklch(0.08 0.02 250))' }} />

      <div style={{ position: 'absolute', top: 54, left: 16, right: 16, display: 'flex', alignItems: 'center', gap: 10 }}>
        <IOSGlassPill dark><div style={{ padding: '0 12px', fontSize: 13, color: '#fff' }}>Voltar</div></IOSGlassPill>
        <div style={{ flex: 1, textAlign: 'center' }}>
          <div style={{ fontSize: 10, color: '#b39cff', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase' }}>Empacotamento · mapa</div>
          <div style={{ fontSize: 14, color: '#fff', fontWeight: 600 }}>Casamento Santos</div>
        </div>
        <IOSGlassPill dark><div style={{ padding: '0 12px', fontSize: 13, color: '#fff' }}>Lista</div></IOSGlassPill>
      </div>

      {/* Warehouse map */}
      <div style={{ position: 'absolute', top: 120, left: 16, right: 16, height: 300, borderRadius: 22,
        background: 'rgba(255,255,255,0.04)', backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
        border: '1px solid rgba(255,255,255,0.1)', padding: 14, overflow: 'hidden' }}>
        <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase', marginBottom: 8 }}>Galpão A · rota otimizada</div>
        <div style={{ position: 'relative', height: 250 }}>
          <svg width="100%" height="100%" viewBox="0 0 340 260" style={{ position: 'absolute', inset: 0 }}>
            {/* Route */}
            <path d="M 50 50 L 200 50 L 275 50 L 275 140 L 125 140 L 50 140 L 50 230 L 125 230" stroke="rgba(179, 156, 255, 0.5)" strokeWidth="2" strokeDasharray="4 4" fill="none" />
          </svg>
          {shelves.map(s => {
            const color = s.active ? '#b39cff' : s.pending2 ? '#ffb75c' : s.pending3 ? '#ff6b6b' : '#6dd18e';
            return (
              <div key={s.id} style={{
                position: 'absolute', left: s.x, top: s.y, width: s.wide ? 140 : 65, height: 60, borderRadius: 8,
                background: `color-mix(in oklch, ${color} 15%, transparent)`,
                border: `1.5px solid ${color}`,
                boxShadow: s.active ? `0 0 20px ${color}` : 'none',
                display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
                fontSize: 10,
              }}>
                <div style={{ color, fontWeight: 600, fontSize: 12, fontFamily: 'var(--font-mono)' }}>{s.id}</div>
                <div style={{ fontSize: 9, color: 'rgba(255,255,255,0.7)', marginTop: 2, fontFamily: 'var(--font-mono)' }}>
                  {s.done ? '✓' : `${s.total - s.pending}/${s.total}`}
                </div>
              </div>
            );
          })}
          {/* "You are here" */}
          <div style={{ position: 'absolute', left: 180, top: 40, width: 20, height: 20, borderRadius: '50%',
            background: '#fff', boxShadow: '0 0 16px #fff', display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 10, color: '#000', fontWeight: 600 }}>●</div>
        </div>
      </div>

      {/* Next pick card */}
      <div style={{ position: 'absolute', top: 440, left: 16, right: 16, padding: 16, borderRadius: 18,
        background: 'rgba(179, 156, 255, 0.1)', backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)',
        border: '1px solid rgba(179, 156, 255, 0.4)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
          <div style={{ padding: '3px 8px', borderRadius: 6, background: '#b39cff', color: '#1a0f2e', fontSize: 11, fontFamily: 'var(--font-mono)', fontWeight: 600 }}>A3</div>
          <div style={{ fontSize: 10, color: '#b39cff', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase' }}>próximo · 3m à frente</div>
        </div>
        <div style={{ fontSize: 17, color: '#fff', fontWeight: 500, letterSpacing: -0.2 }}>Par LED 18x10W</div>
        <div style={{ fontSize: 13, color: 'rgba(255,255,255,0.6)', marginTop: 3 }}>Pegar <b style={{ color: '#fff' }}>4 unidades</b> · sobram 12 na prateleira</div>
      </div>

      {/* Progress strip */}
      <div style={{ position: 'absolute', top: 580, left: 16, right: 16, display: 'flex', gap: 6, alignItems: 'center' }}>
        {[...Array(10)].map((_, i) => (
          <div key={i} style={{ flex: 1, height: 4, borderRadius: 2, background: i < 7 ? '#6dd18e' : i === 7 ? '#b39cff' : 'rgba(255,255,255,0.1)' }} />
        ))}
        <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.6)', fontFamily: 'var(--font-mono)', marginLeft: 8 }}>7/10 prateleiras</div>
      </div>

      {/* Stats */}
      <div style={{ position: 'absolute', top: 610, left: 16, right: 16, display: 'flex', gap: 8 }}>
        {[
          { l: 'Tempo', v: '12:34', sub: 'decorridos' },
          { l: 'Restam', v: '~7 min', sub: 'estimado' },
          { l: 'Progresso', v: '87/214', sub: '41%' },
        ].map(s => (
          <div key={s.l} style={{ flex: 1, padding: 12, borderRadius: 12, background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.08)' }}>
            <div style={{ fontSize: 9, color: 'rgba(255,255,255,0.5)', fontFamily: 'var(--font-mono)', letterSpacing: 0.1, textTransform: 'uppercase' }}>{s.l}</div>
            <div style={{ fontSize: 16, color: '#fff', fontWeight: 500, marginTop: 4, fontFamily: 'var(--font-mono)' }}>{s.v}</div>
            <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.4)', marginTop: 2 }}>{s.sub}</div>
          </div>
        ))}
      </div>

      <div style={{ position: 'absolute', bottom: 50, left: 16, right: 16 }}>
        <div style={{ padding: '13px', borderRadius: 18, textAlign: 'center', background: 'linear-gradient(180deg, rgba(179, 156, 255, 0.95), rgba(179, 156, 255, 0.75))', boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.3), 0 8px 20px rgba(179, 156, 255, 0.3)', color: '#1a0f2e', fontWeight: 600, fontSize: 14 }}>Iniciar coleta em A3</div>
      </div>
    </IOSDevice>
  );
}

Object.assign(window, {
  QRPrintSheet, TagBind, ItemLost, Onboarding, PackingMirror, PackingMap,
});
