import Link from 'next/link'
import { Badge, GlassCard, Ring, StatusDot } from '@/components/mmd/Primitives'
import { setTrainingChapterComplete } from '@/lib/actions/training-progress'
import {
  TRAINING_CONTENT_VERSION,
  TRAINING_LAST_REVIEWED,
  type TrainingTrack,
} from '@/lib/training-content'
import type { TrainingProgressState } from '@/lib/data/training-progress'
import { calculateTrainingProgress } from '@/lib/training-progress-core'
import { TrainingChapterToggle } from './TrainingChapterToggle'

export function TrainingTrackView({
  track,
  progress,
}: {
  track: TrainingTrack
  progress: TrainingProgressState
}) {
  const completed = new Set(progress.completedChapterIds)
  const summary = calculateTrainingProgress(track.chapters, progress.completedChapterIds)

  return (
    <div style={{ display: 'grid', gap: 24, marginTop: 24 }}>
      <Link href="/treinamento" className="training-back">
        ← Voltar às trilhas
      </Link>

      <section className="training-track-hero">
        <div>
          <Badge color={track.id === 'web' ? 'var(--accent-cyan)' : 'var(--accent-violet)'}>
            {track.eyebrow}
          </Badge>
          <h1>{track.title}</h1>
          <p>{track.purpose}</p>
          <div className="training-track-version">
            <span>Versão {TRAINING_CONTENT_VERSION}</span>
            <span>Revisado em {TRAINING_LAST_REVIEWED}</span>
          </div>
        </div>
        <Ring
          value={summary.percent}
          size={128}
          stroke={9}
          label="concluído"
          ariaLabel={`Progresso da trilha ${track.title}`}
        />
      </section>

      {!progress.available && progress.message && (
        <div className="training-state-message" role="status">
          <StatusDot color="var(--accent-amber)" /> {progress.message}
        </div>
      )}

      <section className="training-track-layout">
        <aside className="training-track-aside">
          <GlassCard strong className="training-video-slot">
            <div className="mono training-slot-label">Vídeo da trilha</div>
            <div className="training-video-state">
              <StatusDot color="var(--accent-amber)" />
              <span>Aguardando captação e validação final</span>
            </div>
            <p>
              O vídeo só entra aqui depois do fluxo real passar, sem mock apresentado como hardware.
            </p>
          </GlassCard>

          <nav className="training-chapter-nav" aria-label="Capítulos desta trilha">
            {track.chapters.map((chapter, index) => (
              <a key={chapter.id} href={`#${chapter.id}`}>
                <span>{String(index + 1).padStart(2, '0')}</span>
                <strong>{chapter.title}</strong>
                <small>{chapter.timecode ?? 'A gravar'}</small>
              </a>
            ))}
          </nav>
        </aside>

        <div className="training-chapters">
          <div className="training-section-heading">
            <div>
              <div className="mono">Passo a passo</div>
              <h2>Capítulos</h2>
            </div>
            <span>
              {summary.completed}/{summary.total} concluídos
            </span>
          </div>

          <ol>
            {track.chapters.map((chapter, index) => {
              const isCompleted = completed.has(chapter.id)
              const action = setTrainingChapterComplete.bind(
                null,
                track.id,
                chapter.id,
                !isCompleted,
              )
              return (
                <li id={chapter.id} key={chapter.id} className="glass training-chapter">
                  <div className="training-chapter-index">{String(index + 1).padStart(2, '0')}</div>
                  <div className="training-chapter-copy">
                    <div className="training-chapter-title-row">
                      <h3>{chapter.title}</h3>
                      <span className="mono">{chapter.timecode ?? 'A gravar'}</span>
                    </div>
                    <p>{chapter.summary}</p>
                    <ul>
                      {chapter.steps.map((step) => (
                        <li key={step}>{step}</li>
                      ))}
                    </ul>
                    <div className="training-result">
                      <strong>Resultado:</strong> {chapter.result}
                    </div>
                  </div>
                  <TrainingChapterToggle
                    action={action}
                    completed={isCompleted}
                    disabled={!progress.available}
                  />
                </li>
              )
            })}
          </ol>
        </div>
      </section>

      <section className="training-troubleshooting" aria-labelledby="troubleshooting-title">
        <div className="training-section-heading">
          <div>
            <div className="mono">Recuperação segura</div>
            <h2 id="troubleshooting-title">Quando algo não funciona</h2>
          </div>
        </div>
        <div className="training-troubleshooting-list">
          {track.troubleshooting.map((item) => (
            <details key={item.id} className="glass">
              <summary>{item.title}</summary>
              <dl>
                <div>
                  <dt>Sintoma</dt>
                  <dd>{item.symptom}</dd>
                </div>
                <div>
                  <dt>Causa provável</dt>
                  <dd>{item.likelyCause}</dd>
                </div>
                <div>
                  <dt>Ação segura</dt>
                  <dd>{item.safeAction}</dd>
                </div>
                <div>
                  <dt>Chamar Marco quando</dt>
                  <dd>{item.escalateWhen}</dd>
                </div>
              </dl>
            </details>
          ))}
        </div>
      </section>

      <style>{`
        .training-back { width: fit-content; color: var(--fg-2); text-decoration: none; font-size: 13px; }
        .training-back:hover { color: var(--fg-0); }
        .training-track-hero { display: flex; justify-content: space-between; gap: 24px; align-items: end; }
        .training-track-hero h1 { margin: 16px 0 8px; font-size: clamp(38px, 6vw, 72px); letter-spacing: -.05em; line-height: .96; }
        .training-track-hero p { margin: 0; max-width: 680px; color: var(--fg-2); font-size: clamp(16px, 2vw, 19px); line-height: 1.55; }
        .training-track-version { display: flex; flex-wrap: wrap; gap: 8px 18px; margin-top: 16px; color: var(--fg-3); font: 10px var(--font-mono-raw); text-transform: uppercase; letter-spacing: .08em; }
        .training-state-message { display: flex; gap: 10px; align-items: center; color: var(--accent-amber); font-size: 12px; }
        .training-track-layout { display: grid; grid-template-columns: minmax(240px, 320px) minmax(0, 1fr); gap: 24px; align-items: start; }
        .training-track-aside { display: grid; gap: 14px; position: sticky; top: 20px; }
        .training-video-slot { padding: 20px; border-radius: 8px; min-height: 180px; display: grid; align-content: center; gap: 14px; }
        .training-slot-label { color: var(--fg-3); font-size: 10px; letter-spacing: .1em; text-transform: uppercase; }
        .training-video-state { display: flex; align-items: center; gap: 10px; color: var(--fg-0); font-weight: 600; }
        .training-video-slot p { margin: 0; color: var(--fg-2); font-size: 12px; line-height: 1.5; }
        .training-chapter-nav { display: grid; border-top: 1px solid var(--glass-border); }
        .training-chapter-nav a { display: grid; grid-template-columns: 28px minmax(0, 1fr) auto; gap: 8px; align-items: center; padding: 11px 4px; border-bottom: 1px solid var(--glass-border); color: var(--fg-2); text-decoration: none; }
        .training-chapter-nav a:hover, .training-chapter-nav a:focus-visible { color: var(--fg-0); }
        .training-chapter-nav span, .training-chapter-nav small { font: 9px var(--font-mono-raw); color: var(--fg-3); }
        .training-chapter-nav strong { font-size: 11px; font-weight: 500; }
        .training-section-heading { display: flex; align-items: end; justify-content: space-between; gap: 16px; margin-bottom: 14px; }
        .training-section-heading .mono { color: var(--accent-cyan); font-size: 10px; letter-spacing: .12em; text-transform: uppercase; }
        .training-section-heading h2 { margin: 5px 0 0; font-size: clamp(25px, 4vw, 36px); letter-spacing: -.035em; }
        .training-section-heading > span { color: var(--fg-3); font-size: 12px; }
        .training-chapters > ol { list-style: none; margin: 0; padding: 0; display: grid; gap: 10px; }
        .training-chapter { scroll-margin-top: 20px; display: grid; grid-template-columns: 38px minmax(0, 1fr) auto; gap: 16px; padding: 18px; border-radius: 8px; align-items: start; }
        .training-chapter-index { color: var(--fg-3); font: 11px var(--font-mono-raw); padding-top: 4px; }
        .training-chapter-title-row { display: flex; justify-content: space-between; gap: 12px; align-items: baseline; }
        .training-chapter-title-row h3 { margin: 0; color: var(--fg-0); font-size: 17px; letter-spacing: -.015em; }
        .training-chapter-title-row span { color: var(--fg-3); font-size: 9px; text-transform: uppercase; }
        .training-chapter-copy > p { margin: 7px 0 10px; color: var(--fg-2); font-size: 13px; line-height: 1.5; }
        .training-chapter-copy ul { margin: 0; padding-left: 17px; color: var(--fg-1); font-size: 12px; line-height: 1.65; }
        .training-result { margin-top: 12px; padding-top: 10px; border-top: 1px solid var(--glass-border); color: var(--fg-1); font-size: 12px; }
        .training-troubleshooting { margin-top: 12px; }
        .training-troubleshooting-list { display: grid; gap: 8px; }
        .training-troubleshooting details { border-radius: 8px; padding: 0 16px; }
        .training-troubleshooting summary { cursor: pointer; color: var(--fg-0); font-weight: 600; font-size: 13px; padding: 15px 0; }
        .training-troubleshooting dl { display: grid; gap: 10px; margin: 0; padding: 0 0 16px; }
        .training-troubleshooting dl div { display: grid; grid-template-columns: 130px minmax(0, 1fr); gap: 12px; }
        .training-troubleshooting dt { color: var(--fg-3); font: 9px var(--font-mono-raw); text-transform: uppercase; letter-spacing: .08em; }
        .training-troubleshooting dd { margin: 0; color: var(--fg-2); font-size: 12px; line-height: 1.5; }
        @media (max-width: 940px) {
          .training-track-layout { grid-template-columns: 1fr; }
          .training-track-aside { position: static; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); }
          .training-chapter-nav { max-height: 260px; overflow: auto; }
        }
        @media (max-width: 680px) {
          .training-track-hero { align-items: center; }
          .training-track-hero [role='progressbar'] { display: none; }
          .training-track-aside { grid-template-columns: 1fr; }
          .training-chapter { grid-template-columns: 28px minmax(0, 1fr); }
          .training-chapter form { grid-column: 2; justify-items: start !important; }
          .training-troubleshooting dl div { grid-template-columns: 1fr; gap: 4px; }
        }
      `}</style>
    </div>
  )
}
