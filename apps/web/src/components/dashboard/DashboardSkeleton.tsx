export function DashboardSkeleton() {
  return (
    <div style={{ marginTop: 28 }}>
      <div
        style={{
          marginTop: 36,
          display: 'flex',
          alignItems: 'center',
          gap: 48,
          flexWrap: 'wrap',
        }}
      >
        <div style={{ flex: '1 1 560px', display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div className="skeleton" style={{ width: 180, height: 12 }} />
          <div className="skeleton" style={{ width: '80%', height: 56 }} />
          <div className="skeleton" style={{ width: '60%', height: 56 }} />
          <div className="skeleton" style={{ width: 320, height: 16, marginTop: 12 }} />
        </div>
        <div className="skeleton" style={{ width: 320, height: 320, borderRadius: '50%' }} />
      </div>

      <div
        className="glass"
        style={{
          marginTop: 40,
          display: 'grid',
          gridTemplateColumns: 'repeat(5, minmax(0, 1fr))',
          padding: 0,
          overflow: 'hidden',
        }}
      >
        {Array.from({ length: 5 }).map((_, i) => (
          <div key={i} style={{ padding: '22px 24px', display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div className="skeleton" style={{ width: '60%', height: 10 }} />
            <div className="skeleton" style={{ width: '80%', height: 28 }} />
          </div>
        ))}
      </div>

      <div style={{ marginTop: 36, display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 14 }}>
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="glass" style={{ padding: 18, display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <div className="skeleton" style={{ width: 44, height: 44, borderRadius: '50%' }} />
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6 }}>
                <div className="skeleton" style={{ width: '80%', height: 12 }} />
                <div className="skeleton" style={{ width: '50%', height: 10 }} />
              </div>
            </div>
            <div className="skeleton" style={{ width: '70%', height: 10, marginTop: 8 }} />
          </div>
        ))}
      </div>
    </div>
  )
}
