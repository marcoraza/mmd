// primitives.jsx — shared building blocks for all wireframes
// Exposes: Artboard, Caustic, GlassCard, GlassPill, Ring, StatusDot, IconBox, PlaceholderImg

function Caustic({ orb3 = false, style = {} }) {
  return (
    <div className="caustic-bg" style={style}>
      {orb3 && <div className="orb3" />}
    </div>
  );
}

// An artboard with a title chip above
function Artboard({ label, children, width, height, bg = 'var(--bg-0)', style = {} }) {
  return (
    <div style={{ display: 'inline-flex', flexDirection: 'column', gap: 12, ...style }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 10,
        fontFamily: 'var(--font-mono)', fontSize: 11,
        letterSpacing: 0.08, textTransform: 'uppercase',
        color: 'var(--fg-2)',
      }}>
        <span style={{
          width: 6, height: 6, borderRadius: '50%',
          background: 'var(--accent-cyan)',
        }} />
        {label}
      </div>
      <div style={{
        width, height, background: bg, borderRadius: 'var(--r-xl)',
        position: 'relative', overflow: 'hidden',
        boxShadow: '0 40px 100px rgba(0,0,0,0.35), 0 0 0 1px rgba(255,255,255,0.04)',
      }}>
        {children}
      </div>
    </div>
  );
}

function GlassCard({ children, style = {}, strong = false, noCaustic = false, onClick, className = '' }) {
  return (
    <div
      className={`glass ${strong ? 'glass-strong' : ''} ${className}`}
      onClick={onClick}
      style={style}
    >
      {children}
    </div>
  );
}

function GlassPill({ children, style = {} }) {
  return (
    <div className="glass" style={{
      display: 'inline-flex', alignItems: 'center', gap: 8,
      padding: '8px 14px', borderRadius: 999, fontSize: 13,
      ...style,
    }}>{children}</div>
  );
}

function StatusDot({ color = 'var(--accent-green)', glow = true, size = 8 }) {
  return (
    <span style={{
      width: size, height: size, borderRadius: '50%',
      background: color,
      boxShadow: glow ? `0 0 ${size}px ${color}, 0 0 ${size*2}px ${color}` : 'none',
      display: 'inline-block', flexShrink: 0,
    }} />
  );
}

// A readiness ring — hero component for dashboard
function Ring({ value = 87, size = 180, stroke = 10, label, subLabel, color = 'var(--accent-cyan)' }) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const offset = c * (1 - value / 100);
  return (
    <div style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        <defs>
          <linearGradient id={`ring-grad-${size}-${value}`} x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="oklch(0.80 0.16 210)" />
            <stop offset="50%" stopColor="oklch(0.75 0.17 250)" />
            <stop offset="100%" stopColor="oklch(0.72 0.18 295)" />
          </linearGradient>
        </defs>
        <circle cx={size/2} cy={size/2} r={r} fill="none"
          stroke="var(--glass-border-strong)" strokeWidth={stroke} />
        <circle cx={size/2} cy={size/2} r={r} fill="none"
          stroke={`url(#ring-grad-${size}-${value})`} strokeWidth={stroke}
          strokeDasharray={c} strokeDashoffset={offset} strokeLinecap="round" />
      </svg>
      <div style={{
        position: 'absolute', inset: 0, display: 'flex',
        flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
      }}>
        <div style={{
          fontSize: size * 0.28, fontWeight: 600,
          fontFamily: 'var(--font-sans)',
          letterSpacing: -0.03 * size,
          color: 'var(--fg-0)',
        }}>
          {value}<span style={{ fontSize: size * 0.14, opacity: 0.6, fontWeight: 400 }}>%</span>
        </div>
        {label && <div className="mono" style={{ fontSize: 10, color: 'var(--fg-2)', letterSpacing: 0.08, textTransform: 'uppercase', marginTop: 2 }}>{label}</div>}
        {subLabel && <div style={{ fontSize: 11, color: 'var(--fg-3)', marginTop: 2 }}>{subLabel}</div>}
      </div>
    </div>
  );
}

// Abstract icon box — like a stylized iconography placeholder
function IconBox({ glyph, size = 44, tint = 'var(--accent-cyan-soft)', color = 'var(--accent-cyan)' }) {
  return (
    <div style={{
      width: size, height: size,
      borderRadius: size * 0.28,
      background: tint,
      border: '1px solid var(--glass-border)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      color, flexShrink: 0,
    }}>{glyph}</div>
  );
}

// Diagonal-striped placeholder for imagery
function PlaceholderImg({ label, width = '100%', height = 120, style = {} }) {
  return (
    <div style={{
      width, height,
      background: `repeating-linear-gradient(45deg, rgba(255,255,255,0.04), rgba(255,255,255,0.04) 8px, rgba(255,255,255,0.08) 8px, rgba(255,255,255,0.08) 16px)`,
      border: '1px dashed var(--glass-border-strong)',
      borderRadius: 12,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: 'var(--font-mono)', fontSize: 10, color: 'var(--fg-3)',
      letterSpacing: 0.08, textTransform: 'uppercase',
      ...style,
    }}>{label}</div>
  );
}

// Sparkline svg
function Sparkline({ data, width = 120, height = 32, color = 'var(--accent-cyan)' }) {
  const max = Math.max(...data);
  const min = Math.min(...data);
  const pts = data.map((v, i) => {
    const x = (i / (data.length - 1)) * width;
    const y = height - ((v - min) / (max - min || 1)) * (height - 4) - 2;
    return `${x},${y}`;
  }).join(' ');
  return (
    <svg width={width} height={height}>
      <polyline fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" points={pts} />
    </svg>
  );
}

// Small icons as inline svg
const Icons = {
  search: <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><circle cx="6" cy="6" r="4.5" stroke="currentColor" strokeWidth="1.4"/><path d="M9.5 9.5L12 12" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/></svg>,
  rfid: <svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M3 11 A6 6 0 0 1 9 5 A6 6 0 0 1 15 11" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/><path d="M5.5 11 A3.5 3.5 0 0 1 9 7.5 A3.5 3.5 0 0 1 12.5 11" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/><circle cx="9" cy="11" r="1.3" fill="currentColor"/></svg>,
  qr: <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><rect x="1" y="1" width="5" height="5" stroke="currentColor" strokeWidth="1.2"/><rect x="10" y="1" width="5" height="5" stroke="currentColor" strokeWidth="1.2"/><rect x="1" y="10" width="5" height="5" stroke="currentColor" strokeWidth="1.2"/><rect x="10" y="10" width="2" height="2" fill="currentColor"/><rect x="13" y="10" width="2" height="2" fill="currentColor"/><rect x="10" y="13" width="2" height="2" fill="currentColor"/><rect x="13" y="13" width="2" height="2" fill="currentColor"/></svg>,
  box: <svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M9 1L16.5 5v8L9 17 1.5 13V5L9 1z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round"/><path d="M1.5 5L9 9l7.5-4M9 9v8" stroke="currentColor" strokeWidth="1.3"/></svg>,
  check: <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M2 7.5L5.5 11L12 3.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  x: <svg width="12" height="12" viewBox="0 0 12 12" fill="none"><path d="M2 2L10 10M10 2L2 10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/></svg>,
  arrow: <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M2 7h10M8 3l4 4-4 4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  plus: <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M7 2v10M2 7h10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/></svg>,
  bell: <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M7 1.5a3.5 3.5 0 0 0-3.5 3.5v2L2 9h10l-1.5-2V5A3.5 3.5 0 0 0 7 1.5zM5.5 11a1.5 1.5 0 0 0 3 0" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  chevron: <svg width="10" height="10" viewBox="0 0 10 10" fill="none"><path d="M3.5 2L6.5 5L3.5 8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  dot3: <svg width="14" height="4" viewBox="0 0 14 4" fill="none"><circle cx="2" cy="2" r="1.3" fill="currentColor"/><circle cx="7" cy="2" r="1.3" fill="currentColor"/><circle cx="12" cy="2" r="1.3" fill="currentColor"/></svg>,
  calendar: <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><rect x="1.5" y="3" width="11" height="9.5" rx="1.5" stroke="currentColor" strokeWidth="1.3"/><path d="M1.5 6h11M4.5 1.5v3M9.5 1.5v3" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round"/></svg>,
  zap: <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M8 1L2 8h4l-1 5 6-7H7l1-5z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round" fill="currentColor" fillOpacity="0.15"/></svg>,
  warn: <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M7 1.5l6 10.5H1L7 1.5z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round"/><path d="M7 5.5v3M7 10.5v0.01" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/></svg>,
  package: <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M2 4.5L8 1.5l6 3v7L8 14.5l-6-3v-7z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round"/><path d="M2 4.5L8 7.5l6-3M8 7.5v7" stroke="currentColor" strokeWidth="1.3"/></svg>,
};

Object.assign(window, {
  Caustic, Artboard, GlassCard, GlassPill, Ring, StatusDot, IconBox, PlaceholderImg, Sparkline, Icons,
});
