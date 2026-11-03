import { useEffect, useRef, useState } from 'react'
import { calendarDay, importIcs, planDay, routesWeek } from '../api/client'
import type { DayEntry, TripTrace, WeekResponse } from '../api/types'

const hm = (s?: string) => {
  if (!s) return ''
  const d = new Date(s)
  return isNaN(+d) ? s : d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })
}
const DAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'] as const
type View = 'today' | (typeof DAYS)[number]

export function Today({ onShow }: { onShow: (t: TripTrace) => void }) {
  const [view, setView] = useState<View>('today')
  const [entries, setEntries] = useState<DayEntry[] | null>(null)
  const [src, setSrc] = useState('')
  const [err, setErr] = useState('')
  const [busy, setBusy] = useState(true)
  const week = useRef<WeekResponse | null>(null)
  const file = useRef<HTMLInputElement>(null)

  const load = async () => {
    setBusy(true)
    setErr('')
    try {
      if (view === 'today') {
        const c = await calendarDay()
        const events = Array.isArray(c) ? c : c.events ?? []
        setSrc(Array.isArray(c) ? '' : c.source ?? '')
        setEntries(events.length ? (await planDay(events)).entries : [])
      } else {
        const w = week.current ?? (await routesWeek())
        week.current = w
        setSrc(w.source ?? '')
        setEntries(w.days[view] ?? [])
      }
    } catch (e) {
      setErr(String(e))
    }
    setBusy(false)
  }
  useEffect(() => {
    void load()
  }, [view])

  return (
    <div>
      <div className="seg" role="radiogroup" aria-label="Day">
        {(['today', ...DAYS] as View[]).map((v) => (
          <button key={v} role="radio" aria-checked={view === v} onClick={() => setView(v)}>
            {v === 'today' ? 'Today' : v.slice(0, 3)}
          </button>
        ))}
      </div>
      <div className="row">
        <button className="btn" onClick={() => file.current?.click()}>Import .ics</button>
        <button className="btn" onClick={() => { week.current = null; void load() }}>Refresh</button>
        <input ref={file} type="file" accept=".ics,text/calendar" hidden onChange={async (e) => {
          const f = e.target.files?.[0]
          if (f) {
            try { await importIcs(f); week.current = null; await load() } catch (x) { setErr(String(x)) }
          }
        }} />
      </div>
      {src && <p className="from">Source: {src}</p>}
      {busy && <p role="status">Loading...</p>}
      {err && <p className="err">Could not load ({err}). Is the API running? Start it on http://127.0.0.1:8000.</p>}
      {!busy && !err && entries?.length === 0 && <p>No trips for this day. Import an .ics file to plan one.</p>}
      <ul className="trips">
        {entries?.map((en, i) => (
          <li key={i}>
            <button disabled={!en.trace} onClick={() => en.trace && onShow(en.trace)}>
              <small>{String(en.event.source ?? (src || 'sample'))}</small>
              <b>{en.event.title ?? en.event.summary ?? 'Event'}</b>
              <span>{en.leave_by ? `Leave by ${hm(en.leave_by)}` : ''}{en.event.start ? `  Starts ${hm(en.event.start)}` : ''}</span>
              <span className="rec">{en.needs_place ? 'Needs a place' : en.recommendation ?? ''}</span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  )
}
