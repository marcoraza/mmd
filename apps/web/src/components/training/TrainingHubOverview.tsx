import Link from 'next/link'
import { Badge, GlassCard, Ring, StatusDot } from '@/components/mmd/Primitives'
import {
  TRAINING_CONTENT_VERSION,
  TRAINING_LAST_REVIEWED,
  TRAINING_TRACKS,
  type TrainingTrackId,
} from '@/lib/training-content'
import type { TrainingProgressState } from '@/lib/data/training-progress'
import { calculateTrainingProgress } from '@/lib/training-progress-core'

export function TrainingHubOverview({
  progress,
}: {
  progress: Record<TrainingTrackId, TrainingProgressState>
}) {
  return (
    <div style={{ display: 'grid', gap: 24, marginTop: 28 }}>
      <section className="training-intro">
        <div>
          <Badge color="var(--accent-cyan)">Privado · MMD</Badge>
          <h1 className="training-title">Do planejamento no escritório à conferência no campo.</h1>
          <p className="training-lead">
            Escolha a trilha que corresponde ao trabalho de agora. Web organiza o Evento. iPhone
            executa a operação com RFD40 e QR.
          </p>
        </div>
        <GlassCard strong className="training-status">
          <StatusDot color="var(--accent-amber)" />
          <div>
            <div style={{ color: 'var(--fg-0)', fontWeight: 600 }}>Material em validação</div>
            <div style={{ color: 'var(--fg-2)', fontSize: 12, marginTop: 3 }}>
              Web local verde. Instalação física, Zebra e vídeos ainda pendentes.
            </div>
          </div>
        </GlassCard>
      </section>

      <section className="training-track-grid" aria-label="Trilhas de treinamento">
        {(Object.keys(TRAINING_TRACKS) as TrainingTrackId[]).map((trackId) => {
          const track = TRAINING_TRACKS[trackId]
          const state = progress[trackId]
          const summary = calculateTrainingProgress(track.chapters, state.completedChapterIds)
          return (
            <GlassCard key={track.id} strong className="training-track-card">
              <div className="training-track-card-head">
                <div>
                  <div className="mono training-eyebrow">{track.eyebrow}</div>
                  <h2>{track.title}</h2>
                </div>
                <Ring
                  value={summary.percent}
                  size={92}
                  stroke={7}
                  label="concluído"
                  ariaLabel={`Progresso da trilha ${track.title}`}
                />
              </div>
              <p>{track.purpose}</p>
              <dl className="training-meta">
                <div>
                  <dt>Para quem</dt>
                  <dd>{track.audience}</dd>
                </div>
                <div>
                  <dt>Duração</dt>
                  <dd>{track.durationLabel}</dd>
                </div>
                <div>
                  <dt>Depende de</dt>
                  <dd>{track.dependencyLabel}</dd>
                </div>
              </dl>
              {!state.available && state.message && (
                <div className="training-progress-note">{state.message}</div>
              )}
              <Link href={`/treinamento/${track.id}`} className="training-track-link">
                Abrir trilha <span aria-hidden>→</span>
              </Link>
            </GlassCard>
          )
        })}
      </section>

      <footer className="training-version">
        <span>Versão {TRAINING_CONTENT_VERSION}</span>
        <span>Revisado em {TRAINING_LAST_REVIEWED}</span>
      </footer>

      <style>{`
        .training-intro {
          display: grid;
          grid-template-columns: minmax(0, 1.4fr) minmax(260px, 0.6fr);
          align-items: end;
          gap: 24px;
        }
        .training-title {
          max-width: 780px;
          margin: 18px 0 10px;
          font-size: clamp(34px, 5vw, 64px);
          line-height: .98;
          letter-spacing: -0.045em;
          font-weight: 600;
        }
        .training-lead {
          max-width: 680px;
          color: var(--fg-2);
          font-size: clamp(15px, 1.8vw, 18px);
          line-height: 1.55;
          margin: 0;
        }
        .training-status {
          display: flex;
          gap: 12px;
          align-items: flex-start;
          padding: 18px;
          border-radius: 8px;
        }
        .training-track-grid {
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 16px;
        }
        .training-track-card {
          display: grid;
          gap: 18px;
          padding: clamp(20px, 3vw, 28px);
          border-radius: 8px;
        }
        .training-track-card-head {
          display: flex;
          justify-content: space-between;
          gap: 20px;
          align-items: flex-start;
        }
        .training-track-card h2 {
          margin: 5px 0 0;
          font-size: clamp(24px, 3vw, 34px);
          letter-spacing: -.035em;
        }
        .training-track-card p { margin: 0; color: var(--fg-2); line-height: 1.55; }
        .training-eyebrow { color: var(--accent-cyan); font-size: 10px; letter-spacing: .14em; text-transform: uppercase; }
        .training-meta { display: grid; gap: 11px; margin: 0; }
        .training-meta div { display: grid; grid-template-columns: 92px minmax(0, 1fr); gap: 12px; }
        .training-meta dt { color: var(--fg-3); font: 10px var(--font-mono-raw); letter-spacing: .08em; text-transform: uppercase; }
        .training-meta dd { margin: 0; color: var(--fg-1); font-size: 13px; }
        .training-progress-note { color: var(--accent-amber); font-size: 12px; }
        .training-track-link {
          width: fit-content;
          color: var(--fg-0);
          text-decoration: none;
          font-weight: 600;
          border-bottom: 1px solid var(--accent-cyan);
          padding-bottom: 4px;
        }
        .training-track-link:focus-visible { outline: 2px solid var(--accent-cyan); outline-offset: 4px; }
        .training-version { display: flex; flex-wrap: wrap; gap: 8px 20px; color: var(--fg-3); font: 10px var(--font-mono-raw); letter-spacing: .07em; text-transform: uppercase; }
        @media (max-width: 820px) {
          .training-intro, .training-track-grid { grid-template-columns: 1fr; }
          .training-status { max-width: 560px; }
        }
        @media (max-width: 520px) {
          .training-track-card-head { align-items: center; }
          .training-meta div { grid-template-columns: 1fr; gap: 4px; }
        }
      `}</style>
    </div>
  )
}
