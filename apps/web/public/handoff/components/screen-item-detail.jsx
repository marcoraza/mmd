// screen-item-detail.jsx — Web Item Detail w/ Condition, 3 variations

// ─────────────────────────────────────────────────────────
// V1 — Classic detail: hero image + tabs + condition panel
// ─────────────────────────────────────────────────────────
function ItemDetailV1() {
  return (
    <div style={{ width: DASH_W, height: DASH_H, position: 'relative', background: 'var(--bg-0)' }}>
      <Caustic />
      <SideRail active="inventory" />

      <div style={{ position: 'absolute', left: 80, right: 0, top: 0, bottom: 0, padding: '28px 32px', overflow: 'hidden' }}>
        <TopBar />

        {/* breadcrumb */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 18, fontSize: 12, color: 'var(--fg-2)' }}>
          <span>Inventário</span>
          <span style={{ color: 'var(--fg-3)' }}>/</span>
          <span>Iluminação</span>
          <span style={{ color: 'var(--fg-3)' }}>/</span>
          <span style={{ color: 'var(--fg-0)' }}>Par LED 18x10W RGBW</span>
          <span className="mono" style={{ color: 'var(--fg-3)', marginLeft: 6, fontSize: 11 }}>#012</span>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1.3fr 1fr', gap: 20, marginTop: 16, height: 'calc(100% - 110px)' }}>
          {/* Left */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16, minHeight: 0 }}>
            <GlassCard strong style={{ padding: 22, display: 'flex', gap: 20 }}>
              <PlaceholderImg label="foto · par led rgbw" width={180} height={180} style={{ flexShrink: 0, borderRadius: 16 }} />
              <div style={{ flex: 1 }}>
                <div className="mono" style={{ fontSize: 10, color: 'var(--accent-cyan)', letterSpacing: 0.12, textTransform: 'uppercase' }}>Unidade física · serial #012</div>
                <div style={{ fontSize: 26, fontWeight: 500, color: 'var(--fg-0)', letterSpacing: -0.5, marginTop: 4, lineHeight: 1.15 }}>Par LED 18x10W RGBW</div>
                <div style={{ fontSize: 13, color: 'var(--fg-2)', marginTop: 6 }}>Chauvet · COLORband PiX · Iluminação</div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginTop: 18 }}>
                  <DetailKV label="Código interno" value="MMD-ILU-0042-012" mono />
                  <DetailKV label="Tag RFID" value="E280 6894 A8B0 C412" mono />
                  <DetailKV label="Serial fábrica" value="CH2024-8821A" mono />
                  <DetailKV label="Localização" value="Estoque A · Prateleira 3" />
                </div>

                <div style={{ display: 'flex', gap: 8, marginTop: 18 }}>
                  <PrimaryBtn small>Imprimir QR</PrimaryBtn>
                  <GhostBtn small>Editar</GhostBtn>
                  <GhostBtn small>Vincular tag</GhostBtn>
                </div>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
                <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)' }}>STATUS</div>
                <div style={{
                  padding: '10px 18px', borderRadius: 999, fontSize: 14, fontWeight: 500,
                  background: 'color-mix(in oklch, var(--accent-green) 18%, transparent)',
                  border: '1px solid color-mix(in oklch, var(--accent-green) 40%, transparent)',
                  color: 'var(--accent-green)',
                  display: 'inline-flex', alignItems: 'center', gap: 8,
                }}>
                  <StatusDot color="var(--accent-green)" size={8} /> Disponível
                </div>
                <div style={{ fontSize: 11, color: 'var(--fg-3)' }}>desde 20.abr</div>
              </div>
            </GlassCard>

            {/* Tabs */}
            <div style={{ display: 'flex', gap: 4 }}>
              {['Histórico', 'Movimentações', 'Manutenção', 'Documentos'].map((t, i) => (
                <div key={i} style={{
                  padding: '8px 14px', fontSize: 13, borderRadius: 10, cursor: 'pointer',
                  background: i === 0 ? 'var(--glass-bg-strong)' : 'transparent',
                  border: '1px solid', borderColor: i === 0 ? 'var(--glass-border-strong)' : 'transparent',
                  color: i === 0 ? 'var(--fg-0)' : 'var(--fg-2)',
                }}>{t}</div>
              ))}
            </div>

            {/* Timeline */}
            <GlassCard style={{ padding: 22, flex: 1, minHeight: 0, overflow: 'auto' }}>
              <div style={{ fontSize: 13, color: 'var(--fg-2)', marginBottom: 14 }} className="mono">CICLO DE VIDA · 47 EVENTOS</div>
              <div style={{ position: 'relative', paddingLeft: 18 }}>
                <div style={{ position: 'absolute', left: 5, top: 4, bottom: 4, width: 1, background: 'var(--glass-border-strong)' }} />
                {[
                  { t: 'Hoje · 09:12', s: 'RETORNO · Casamento anterior', c: 'var(--accent-green)', desc: 'Retornou OK · desgaste 4/5' },
                  { t: '18.abr · 14:03', s: 'SAÍDA · Festival Outono', c: 'var(--accent-violet)', desc: 'Packing list validado por Gabriel · RFID lote' },
                  { t: '10.abr · 16:45', s: 'MANUTENÇÃO · LED queimada', c: 'var(--accent-amber)', desc: 'Substituição de 2 LEDs · R$ 45' },
                  { t: '02.abr · 11:20', s: 'RETORNO · Corporativo ABC', c: 'var(--accent-green)', desc: 'Retornou com defeito → manutenção' },
                  { t: '28.mar · 08:15', s: 'SAÍDA · Corporativo ABC', c: 'var(--accent-violet)', desc: 'Packing list validado' },
                ].map((e, i) => (
                  <div key={i} style={{ position: 'relative', paddingBottom: 16 }}>
                    <div style={{ position: 'absolute', left: -17, top: 4, width: 10, height: 10, borderRadius: '50%', background: e.c, boxShadow: `0 0 0 3px var(--bg-0), 0 0 10px ${e.c}` }} />
                    <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.08 }}>{e.t}</div>
                    <div style={{ fontSize: 13, color: 'var(--fg-0)', fontWeight: 500, marginTop: 2 }}>{e.s}</div>
                    <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 2 }}>{e.desc}</div>
                  </div>
                ))}
              </div>
            </GlassCard>
          </div>

          {/* Right — condition panel */}
          <GlassCard strong style={{ padding: 22, overflow: 'auto' }}>
            <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', letterSpacing: 0.12 }}>SAÚDE PATRIMONIAL</div>
            <div style={{ fontSize: 16, fontWeight: 500, marginTop: 4, marginBottom: 20 }}>Condição da unidade</div>

            {/* Big desgaste */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 20, marginBottom: 24 }}>
              <Ring value={80} size={110} stroke={8} label="desgaste" subLabel="4 de 5" color="var(--accent-green)" />
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 11, color: 'var(--fg-2)' }} className="mono">AVALIAÇÃO</div>
                <div style={{ fontSize: 22, fontWeight: 500, color: 'var(--accent-green)', marginTop: 4, letterSpacing: -0.3 }}>Bom estado</div>
                <div style={{ fontSize: 11, color: 'var(--fg-3)', marginTop: 6 }}>Última avaliação · 20.abr</div>
              </div>
            </div>

            {/* Estado */}
            <div style={{ marginBottom: 20 }}>
              <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', marginBottom: 8 }}>ESTADO · ciclo de vida</div>
              <div style={{ display: 'flex', gap: 4 }}>
                {['NOVO', 'SEMI', 'USADO', 'RECOND.'].map((s, i) => (
                  <div key={i} style={{
                    flex: 1, padding: '8px 6px', textAlign: 'center', borderRadius: 8,
                    background: i === 2 ? 'color-mix(in oklch, var(--accent-cyan) 22%, transparent)' : 'var(--glass-bg)',
                    border: '1px solid', borderColor: i === 2 ? 'var(--accent-cyan-soft)' : 'var(--glass-border)',
                    fontSize: 10, color: i === 2 ? 'var(--accent-cyan)' : 'var(--fg-3)',
                    fontWeight: 500, letterSpacing: 0.04,
                  }} className="mono">{s}</div>
                ))}
              </div>
            </div>

            {/* Depreciação */}
            <div style={{ marginBottom: 20 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
                <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)' }}>DEPRECIAÇÃO</div>
                <div className="mono" style={{ fontSize: 11, color: 'var(--fg-1)' }}>65% restante</div>
              </div>
              <div style={{ height: 10, borderRadius: 5, background: 'var(--glass-border)', overflow: 'hidden', position: 'relative' }}>
                <div style={{
                  width: '65%', height: '100%',
                  background: 'linear-gradient(90deg, oklch(0.75 0.17 150), oklch(0.80 0.16 210))',
                  boxShadow: '0 0 10px oklch(0.80 0.16 210 / 0.5)',
                }} />
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6 }} className="mono">
                <span style={{ fontSize: 10, color: 'var(--fg-3)' }}>0%</span>
                <span style={{ fontSize: 10, color: 'var(--fg-3)' }}>100%</span>
              </div>
            </div>

            {/* Values */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 20 }}>
              <GlassCard style={{ padding: 14 }}>
                <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)' }}>VALOR ORIGINAL</div>
                <div style={{ fontSize: 18, fontWeight: 500, color: 'var(--fg-1)', marginTop: 4 }}>R$ 1.200</div>
              </GlassCard>
              <GlassCard style={{ padding: 14 }}>
                <div className="mono" style={{ fontSize: 10, color: 'var(--accent-cyan)' }}>VALOR ATUAL</div>
                <div style={{ fontSize: 18, fontWeight: 500, color: 'var(--fg-0)', marginTop: 4 }}>R$ 780</div>
              </GlassCard>
            </div>

            {/* Calc */}
            <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', padding: 12, background: 'rgba(0,0,0,0.2)', borderRadius: 10, lineHeight: 1.6 }}>
              valor_atual = 1200 × (4/5) × 0.65<br/>
              = 1200 × 0.80 × 0.65<br/>
              = <span style={{ color: 'var(--accent-cyan)' }}>R$ 624</span>
            </div>
          </GlassCard>
        </div>
      </div>
    </div>
  );
}

function DetailKV({ label, value, mono }) {
  return (
    <div>
      <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', letterSpacing: 0.08, textTransform: 'uppercase' }}>{label}</div>
      <div style={{ fontSize: 13, color: 'var(--fg-1)', marginTop: 2, fontFamily: mono ? 'var(--font-mono)' : 'var(--font-sans)' }}>{value}</div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────
// V2 — Cinematic 3D card + condition dials
// ─────────────────────────────────────────────────────────
function ItemDetailV2() {
  return (
    <div style={{ width: DASH_W, height: DASH_H, position: 'relative', background: 'var(--bg-0)' }}>
      <Caustic orb3 />
      <SideRail active="inventory" />

      <div style={{ position: 'absolute', left: 80, right: 0, top: 0, bottom: 0, padding: '28px 40px', overflow: 'hidden' }}>
        <TopBar />

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 32, marginTop: 32, height: 'calc(100% - 100px)' }}>
          {/* Floating hero card with depth */}
          <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            {/* shadow layers behind */}
            <div style={{ position: 'absolute', width: 340, height: 340, borderRadius: 40, background: 'radial-gradient(circle, oklch(0.72 0.18 250 / 0.45), transparent 60%)', filter: 'blur(40px)' }} />

            <GlassCard strong style={{
              padding: 32, width: 360, transform: 'perspective(1000px) rotateY(-8deg) rotateX(4deg)',
              boxShadow: '0 60px 120px rgba(0,0,0,0.5), 0 0 0 1px rgba(255,255,255,0.1)',
            }}>
              <PlaceholderImg label="par led rgbw" width="100%" height={240} style={{ borderRadius: 16, marginBottom: 20 }} />
              <div className="mono" style={{ fontSize: 10, color: 'var(--accent-cyan)', letterSpacing: 0.12 }}>MMD-ILU-0042-012</div>
              <div style={{ fontSize: 22, fontWeight: 500, letterSpacing: -0.4, marginTop: 4 }}>Par LED 18x10W RGBW</div>
              <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 4 }}>Chauvet · COLORband PiX</div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 20, padding: '12px 0', borderTop: '1px solid var(--glass-border)' }}>
                <div>
                  <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>STATUS</div>
                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 13, color: 'var(--accent-green)', marginTop: 2, fontWeight: 500 }}>
                    <StatusDot color="var(--accent-green)" size={6} /> Disponível
                  </div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>VALOR ATUAL</div>
                  <div style={{ fontSize: 16, fontWeight: 500, color: 'var(--fg-0)', marginTop: 2 }}>R$ 624</div>
                </div>
              </div>
            </GlassCard>

            {/* QR card floating */}
            <GlassCard style={{
              position: 'absolute', bottom: 40, left: 10,
              padding: 14, width: 120,
              transform: 'perspective(1000px) rotateY(8deg) rotateX(-4deg)',
            }}>
              <div style={{ width: 92, height: 92, background: `
                repeating-linear-gradient(0deg, var(--fg-0) 0 6px, transparent 6px 10px),
                repeating-linear-gradient(90deg, var(--fg-0) 0 6px, transparent 6px 10px)
              `, borderRadius: 6, marginBottom: 8 }} />
              <div className="mono" style={{ fontSize: 9, color: 'var(--fg-2)', textAlign: 'center' }}>ILU-0042-012</div>
            </GlassCard>
          </div>

          {/* Right — large dials */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 18, overflow: 'auto' }}>
            <div>
              <div className="mono" style={{ fontSize: 10, color: 'var(--accent-cyan)', letterSpacing: 0.12 }}>SAÚDE PATRIMONIAL</div>
              <div style={{ fontSize: 32, fontWeight: 500, letterSpacing: -0.8, marginTop: 4 }}>Boa condição</div>
              <div style={{ fontSize: 13, color: 'var(--fg-2)', marginTop: 6 }}>Esta unidade está USADA mas ainda retém 65% do valor original. Recomendado uso contínuo.</div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12 }}>
              <GlassCard style={{ padding: 16, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
                <Ring value={80} size={90} stroke={6} label="desgaste" color="var(--accent-green)" />
                <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>4 de 5</div>
              </GlassCard>
              <GlassCard style={{ padding: 16, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
                <Ring value={65} size={90} stroke={6} label="depreciação" color="var(--accent-cyan)" />
                <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>restante</div>
              </GlassCard>
              <GlassCard style={{ padding: 16, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
                <div style={{ width: 90, height: 90, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
                  <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)' }}>ESTADO</div>
                  <div style={{ fontSize: 15, fontWeight: 500, color: 'var(--accent-cyan)', marginTop: 4 }}>USADO</div>
                  <div className="mono" style={{ fontSize: 9, color: 'var(--fg-3)', marginTop: 2 }}>fator 0.65</div>
                </div>
                <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>ciclo de vida</div>
              </GlassCard>
            </div>

            <GlassCard style={{ padding: 20 }}>
              <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', letterSpacing: 0.12, marginBottom: 12 }}>EVOLUÇÃO · 12 MESES</div>
              <Sparkline data={[5, 5, 5, 4, 4, 4, 4, 4, 4, 4, 4, 4]} width={280} height={60} color="var(--accent-green)" />
              <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10, fontSize: 11, color: 'var(--fg-3)' }}>
                <span>Desgaste entrou em 5 · hoje em 4</span>
                <span className="mono">47 usos</span>
              </div>
            </GlassCard>

            <GlassCard style={{ padding: 20 }}>
              <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', letterSpacing: 0.12, marginBottom: 10 }}>UTILIZAÇÃO</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
                <div>
                  <div style={{ fontSize: 28, fontWeight: 500, letterSpacing: -0.5 }}>47</div>
                  <div style={{ fontSize: 11, color: 'var(--fg-3)' }}>eventos</div>
                </div>
                <div style={{ height: 36, width: 1, background: 'var(--glass-border)' }} />
                <div>
                  <div style={{ fontSize: 28, fontWeight: 500, letterSpacing: -0.5 }}>312<span style={{ fontSize: 14, color: 'var(--fg-3)' }}>h</span></div>
                  <div style={{ fontSize: 11, color: 'var(--fg-3)' }}>em campo</div>
                </div>
                <div style={{ height: 36, width: 1, background: 'var(--glass-border)' }} />
                <div>
                  <div style={{ fontSize: 28, fontWeight: 500, letterSpacing: -0.5 }}>R$ 18,2<span style={{ fontSize: 14, color: 'var(--fg-3)' }}>k</span></div>
                  <div style={{ fontSize: 11, color: 'var(--fg-3)' }}>receita gerada</div>
                </div>
              </div>
            </GlassCard>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────
// V3 — Data-dense inspector (for power users)
// ─────────────────────────────────────────────────────────
function ItemDetailV3() {
  return (
    <div style={{ width: DASH_W, height: DASH_H, position: 'relative', background: 'var(--bg-0)' }}>
      <Caustic />
      <SideRail active="inventory" />

      <div style={{ position: 'absolute', left: 80, right: 0, top: 0, bottom: 0, padding: '28px 32px', overflow: 'hidden' }}>
        <TopBar />

        {/* Top strip — quick scan header */}
        <GlassCard strong style={{ marginTop: 18, padding: '18px 22px', display: 'flex', alignItems: 'center', gap: 20 }}>
          <PlaceholderImg label="par led" width={72} height={72} style={{ flexShrink: 0, borderRadius: 14 }} />
          <div style={{ flex: 1 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <span style={{ fontSize: 20, fontWeight: 500, color: 'var(--fg-0)', letterSpacing: -0.4 }}>Par LED 18x10W RGBW</span>
              <span className="mono" style={{ fontSize: 11, color: 'var(--fg-2)', padding: '3px 8px', background: 'var(--glass-bg-strong)', borderRadius: 6 }}>MMD-ILU-0042-012</span>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11, color: 'var(--accent-green)', padding: '3px 10px', background: 'color-mix(in oklch, var(--accent-green) 15%, transparent)', borderRadius: 999, fontWeight: 500 }}>
                <StatusDot color="var(--accent-green)" size={6} /> DISPONÍVEL
              </span>
            </div>
            <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 4, display: 'flex', gap: 16 }}>
              <span>Chauvet COLORband PiX</span>
              <span>·</span>
              <span>Iluminação / Par LED</span>
              <span>·</span>
              <span>Estoque A · Prateleira 3</span>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            <GhostBtn small>← Anterior</GhostBtn>
            <GhostBtn small>Próximo →</GhostBtn>
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            <PrimaryBtn small>Editar</PrimaryBtn>
          </div>
        </GlassCard>

        {/* Grid of panels */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 14, marginTop: 14, height: 'calc(100% - 200px)' }}>
          {/* Identificação */}
          <GlassCard style={{ padding: 18, overflow: 'auto' }}>
            <div className="mono" style={{ fontSize: 10, color: 'var(--accent-cyan)', letterSpacing: 0.12, marginBottom: 12 }}>IDENTIFICAÇÃO</div>
            {[
              ['Código interno', 'MMD-ILU-0042-012', true],
              ['Tag RFID', 'E280 6894 A8B0 C412', true],
              ['QR Code', 'QR-ILU-0042-012', true],
              ['Serial fábrica', 'CH2024-8821A', true],
              ['ID interno', '#8342', true],
            ].map(([k, v, m], i) => (
              <div key={i} style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0', borderTop: i === 0 ? 'none' : '1px solid var(--glass-border)' }}>
                <span style={{ fontSize: 12, color: 'var(--fg-2)' }}>{k}</span>
                <span style={{ fontSize: 12, color: 'var(--fg-0)', fontFamily: m ? 'var(--font-mono)' : 'var(--font-sans)' }}>{v}</span>
              </div>
            ))}
          </GlassCard>

          {/* Condição */}
          <GlassCard strong style={{ padding: 18, overflow: 'auto' }}>
            <div className="mono" style={{ fontSize: 10, color: 'var(--accent-cyan)', letterSpacing: 0.12, marginBottom: 12 }}>CONDIÇÃO</div>

            <div style={{ marginBottom: 14 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                <span style={{ fontSize: 12, color: 'var(--fg-2)' }}>Desgaste</span>
                <span className="mono" style={{ fontSize: 12, color: 'var(--accent-green)' }}>4 / 5</span>
              </div>
              <div style={{ display: 'flex', gap: 4 }}>
                {[1, 2, 3, 4, 5].map(n => (
                  <div key={n} style={{
                    flex: 1, height: 8, borderRadius: 4,
                    background: n <= 4 ? 'var(--accent-green)' : 'var(--glass-border)',
                    boxShadow: n <= 4 ? '0 0 8px var(--accent-green)' : 'none',
                    opacity: n <= 4 ? 1 - (4 - n) * 0.15 : 1,
                  }} />
                ))}
              </div>
            </div>

            <div style={{ marginBottom: 14 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                <span style={{ fontSize: 12, color: 'var(--fg-2)' }}>Estado</span>
                <span className="mono" style={{ fontSize: 12, color: 'var(--accent-cyan)' }}>USADO</span>
              </div>
              <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)' }}>fator 0.65</div>
            </div>

            <div style={{ marginBottom: 14 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                <span style={{ fontSize: 12, color: 'var(--fg-2)' }}>Depreciação</span>
                <span className="mono" style={{ fontSize: 12, color: 'var(--fg-0)' }}>65%</span>
              </div>
              <div style={{ height: 6, borderRadius: 3, background: 'var(--glass-border)', overflow: 'hidden' }}>
                <div style={{ width: '65%', height: '100%', background: 'linear-gradient(90deg, var(--accent-cyan), var(--accent-violet))' }} />
              </div>
            </div>

            <div style={{ padding: 12, background: 'rgba(0,0,0,0.3)', borderRadius: 10, marginTop: 16 }}>
              <div className="mono" style={{ fontSize: 9, color: 'var(--fg-3)', marginBottom: 6 }}>CÁLCULO</div>
              <div className="mono" style={{ fontSize: 11, color: 'var(--fg-1)', lineHeight: 1.8 }}>
                1200 × (4/5) × 0.65<br/>
                = <span style={{ color: 'var(--accent-cyan)' }}>R$ 624</span>
              </div>
            </div>
          </GlassCard>

          {/* Histórico */}
          <GlassCard style={{ padding: 18, overflow: 'auto' }}>
            <div className="mono" style={{ fontSize: 10, color: 'var(--accent-cyan)', letterSpacing: 0.12, marginBottom: 12 }}>ÚLTIMAS MOVIMENTAÇÕES</div>
            {[
              { t: 'hoje 09:12', a: 'Retorno', p: 'Fest. Outono', m: 'rfid', c: 'var(--accent-green)' },
              { t: '18.abr', a: 'Saída', p: 'Fest. Outono', m: 'rfid', c: 'var(--accent-violet)' },
              { t: '10.abr', a: 'Manutenção', p: '-', m: 'manual', c: 'var(--accent-amber)' },
              { t: '02.abr', a: 'Retorno', p: 'Corp ABC', m: 'qr', c: 'var(--accent-green)' },
              { t: '28.mar', a: 'Saída', p: 'Corp ABC', m: 'rfid', c: 'var(--accent-violet)' },
              { t: '25.mar', a: 'Retorno', p: 'Banda X', m: 'rfid', c: 'var(--accent-green)' },
              { t: '22.mar', a: 'Saída', p: 'Banda X', m: 'rfid', c: 'var(--accent-violet)' },
            ].map((m, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 0', borderTop: i === 0 ? 'none' : '1px solid var(--glass-border)' }}>
                <StatusDot color={m.c} size={6} glow={false} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 12, color: 'var(--fg-0)' }}>{m.a} · <span style={{ color: 'var(--fg-2)' }}>{m.p}</span></div>
                </div>
                <div className="mono" style={{ fontSize: 10, color: 'var(--accent-cyan)' }}>{m.m}</div>
                <div className="mono" style={{ fontSize: 10, color: 'var(--fg-3)', width: 52, textAlign: 'right' }}>{m.t}</div>
              </div>
            ))}
          </GlassCard>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { ItemDetailV1, ItemDetailV2, ItemDetailV3 });
