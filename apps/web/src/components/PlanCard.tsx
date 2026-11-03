import type { TripTrace } from '../api/types'
import type { Progress } from './Sim'

const min = (s: number) => Math.round(s / 60)
const t = (iso: string) => {
  const d = new Date(iso)
  return isNaN(+d) ? iso : d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })
}
const color = (id?: string | null) => {
  if (!id) return '#8a96a3'
  const k = id.toLowerCase()
  return k.includes('red') ? '#e04b4b' : k.includes('blue') ? '#4b8be0' : k.includes('green') ? '#3fb36b' : k.includes('trolley') ? '#e0a84b' : '#B3A369'
}

export function PlanCard({ trace, walking, progress, arrived, onWalk, onStop }: {
  trace: TripTrace; walking: boolean; progress: Progress | null; arrived: boolean; onWalk: () => void; onStop: () => void
}) {
  const p = trace.plan
  const { p10, p50, p90 } = p.total_s
  const span = p90 - p10 || 1
  const lastWalk = p.legs.map((l) => l.kind).lastIndexOf('walk')
  return (
    <section className="card" aria-label="Plan">
      <h3>{trace.origin_name ?? 'Start'} to {trace.destination_name ?? 'destination'}</h3>
      <div className="facts">
        <div><b>{t(p.leave_at)}</b>leave by</div>
        <div><b>{t(p.arrive_at)}</b>arrive</div>
      </div>
      {p.p_on_time != null && (
        <p className={`ontime ${p.p_on_time >= 0.85 ? 'hi' : p.p_on_time >= 0.6 ? 'mid' : 'lo'}`}>
          {p.p_on_time >= 0.85 ? 'Very likely on time' : p.p_on_time >= 0.6 ? 'Likely on time' : p.p_on_time >= 0.4 ? 'Toss-up' : 'Likely late'}
          <b>{Math.round(p.p_on_time * 100)}% on time</b>
        </p>
      )}
      <ol className="legs">
        {p.legs.map((l, i) => {
          const active = walking && progress?.leg_index === i
          return (
            <li key={i} className={active ? 'active' : ''} aria-current={active ? 'step' : undefined}>
              <span className="chip" style={{ background: color(l.route_id) }} />
              <span className="lbl">
                {l.kind === 'walk' && i === lastWalk && i > 0 ? 'Final walk: ' : ''}{l.label}
                {l.kind === 'walk' && l.estimate && <em>estimate</em>}
                {l.synthetic && <em>{l.route_id && /blue/i.test(l.route_id) ? 'Blue synthetic' : 'synthetic'}</em>}
              </span>
              <span>{min(l.duration_s_p50)} min</span>
            </li>
          )
        })}
      </ol>
      <p className="bandtitle">Likely arrival range: {min(p10)} to {min(p90)} min trip</p>
      <div className="band" role="img" aria-label={`Total ${min(p10)} to ${min(p90)} minutes, median ${min(p50)}`}>
        <i style={{ left: `${((p50 - p10) / span) * 100}%` }} />
      </div>
      <div className="bandlbl"><span>{min(p10)} min</span><span>median {min(p50)}</span><span>{min(p90)} min</span></div>
      {(trace.confidence_horizon_s ?? 0) >= 3600 && <p className="note">Check again closer to departure.</p>}
      <div aria-live="polite" className="note">
        {arrived ? 'Arrived' : walking && progress ? `Walking: ${p.legs[progress.leg_index]?.label ?? progress.leg_kind} (${Math.round(progress.fraction * 100)}%)` : ''}
      </div>
      {walking ? <button className="btn" onClick={onStop}>Stop</button> : <button className="btn gold" onClick={onWalk}>Walk this path</button>}
    </section>
  )
}
