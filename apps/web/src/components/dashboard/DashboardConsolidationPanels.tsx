import type { DashboardCategoryUsage, DashboardMaintenanceSignal } from '@/lib/data/dashboard'

function pctWidth(value: number) {
  return `${Math.max(4, Math.min(100, value))}%`
}

export function DashboardConsolidationPanels({
  categories,
  maintenance,
}: {
  categories: DashboardCategoryUsage[]
  maintenance: DashboardMaintenanceSignal[]
}) {
  return (
    <section className="dashboard-panels reveal reveal-4" style={{ marginTop: 18 }}>
      <div className="glass dashboard-panel">
        <div className="dashboard-panel__header">
          <span>Uso por categoria</span>
          <span className="mono">{categories.length} categorias</span>
        </div>

        <div className="dashboard-panel__body">
          {categories.length === 0 ? (
            <div className="dashboard-empty">Sem packing ativo para consolidar.</div>
          ) : (
            categories.map((category) => (
              <div key={category.categoria} className="dashboard-category-row">
                <div className="dashboard-category-row__top">
                  <span>{category.label}</span>
                  <span className="mono">
                    {category.covered}/{category.required}
                  </span>
                </div>
                <div className="dashboard-meter" aria-hidden>
                  <div
                    style={{
                      width: pctWidth(category.readiness),
                      background: category.color,
                    }}
                  />
                </div>
                <div className="mono dashboard-category-row__pct">{category.readiness}%</div>
              </div>
            ))
          )}
        </div>
      </div>

      <div className="glass dashboard-panel">
        <div className="dashboard-panel__header">
          <span>Manutenção e perdas</span>
          <span className="mono">estoque real</span>
        </div>

        <div className="dashboard-maintenance-grid">
          {maintenance.map((signal) => (
            <div key={signal.id} className="dashboard-maintenance-row">
              <div>
                <div className="dashboard-maintenance-row__label">{signal.label}</div>
                <div className="dashboard-maintenance-row__detail">{signal.detail}</div>
              </div>
              <div className="dashboard-maintenance-row__value" style={{ color: signal.color }}>
                {signal.value}
              </div>
            </div>
          ))}
        </div>
      </div>

      <style>{`
        .dashboard-panels {
          display: grid;
          grid-template-columns: minmax(0, 1.1fr) minmax(320px, 0.9fr);
          gap: 18px;
        }
        .dashboard-panel {
          border-radius: var(--r-lg);
          padding: 20px;
          min-width: 0;
        }
        .dashboard-panel__header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 14px;
          color: var(--fg-1);
          font-size: 14px;
          font-weight: 500;
          margin-bottom: 16px;
        }
        .dashboard-panel__header .mono {
          font-size: 10px;
          color: var(--fg-3);
          text-transform: uppercase;
          letter-spacing: 0;
        }
        .dashboard-panel__body {
          display: grid;
          gap: 12px;
        }
        .dashboard-empty {
          border: 1px dashed var(--glass-border-strong);
          border-radius: var(--r-sm);
          padding: 18px;
          color: var(--fg-2);
          font-size: 13px;
        }
        .dashboard-category-row {
          display: grid;
          grid-template-columns: minmax(0, 1fr) 48px;
          gap: 8px 12px;
          align-items: center;
        }
        .dashboard-category-row__top {
          grid-column: 1 / -1;
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 12px;
          min-width: 0;
          color: var(--fg-1);
          font-size: 13px;
        }
        .dashboard-category-row__top .mono {
          color: var(--fg-3);
          font-size: 10px;
          letter-spacing: 0;
        }
        .dashboard-meter {
          height: 7px;
          border-radius: 999px;
          background: color-mix(in oklch, var(--fg-0) 10%, transparent);
          overflow: hidden;
        }
        .dashboard-meter > div {
          height: 100%;
          border-radius: inherit;
          box-shadow: 0 0 16px color-mix(in oklch, currentColor 24%, transparent);
        }
        .dashboard-category-row__pct {
          justify-self: end;
          color: var(--fg-2);
          font-size: 10px;
          letter-spacing: 0;
        }
        .dashboard-maintenance-grid {
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 12px;
        }
        .dashboard-maintenance-row {
          min-height: 92px;
          border: 1px solid var(--glass-border);
          border-radius: var(--r-sm);
          padding: 14px;
          display: flex;
          align-items: flex-start;
          justify-content: space-between;
          gap: 12px;
          background: color-mix(in oklch, var(--glass-bg) 70%, transparent);
        }
        .dashboard-maintenance-row__label {
          color: var(--fg-1);
          font-size: 12px;
          font-weight: 500;
          text-transform: uppercase;
          letter-spacing: 0;
        }
        .dashboard-maintenance-row__detail {
          margin-top: 8px;
          color: var(--fg-3);
          font-size: 11px;
          line-height: 1.35;
        }
        .dashboard-maintenance-row__value {
          font-size: 30px;
          font-weight: 500;
          line-height: 1;
        }
        @media (max-width: 980px) {
          .dashboard-panels {
            grid-template-columns: 1fr;
          }
        }
        @media (max-width: 560px) {
          .dashboard-panel {
            padding: 16px;
          }
          .dashboard-maintenance-grid {
            grid-template-columns: 1fr;
          }
        }
      `}</style>
    </section>
  )
}
