interface PageHeaderProps {
  title: string
  subtitle?: string
  action?: React.ReactNode
}

export function PageHeader({ title, subtitle, action }: PageHeaderProps) {
  return (
    <div
      className="flex items-start justify-between px-8 py-6"
      style={{ borderBottom: '1px solid #E8E8E8' }}
    >
      <div>
        <h1 style={{ fontFamily: '"Space Grotesk", sans-serif', fontSize: 18, fontWeight: 600, color: '#000000', margin: 0 }}>
          {title}
        </h1>
        {subtitle && (
          <p style={{ fontFamily: '"Space Mono", monospace', fontSize: 10, color: '#999999', letterSpacing: '0.1em', marginTop: 4 }}>
            {subtitle.toUpperCase()}
          </p>
        )}
      </div>
      {action && <div>{action}</div>}
    </div>
  )
}
