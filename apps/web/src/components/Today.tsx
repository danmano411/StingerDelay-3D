import { useEffect, useRef, useState } from 'react'
import { calendarDay, importIcs, planDay } from '../api/client'
import type { DayEntry, TripTrace } from '../api/types'

const hm = (s?: string) => {
  if (!s) return ''
  const d = new Date(s)
  return isNaN(+d) ? s : d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })
}

export function Today({ onShow }: { onShow: (t: TripTrace) => void }) {
  const [entries, setEntries] = useState<DayEntry[] | null>(null)
  const [err, setErr] = useState('')
  const [busy, setBusy] = useState(true)
  const file = useRef<HTMLInputElement>(null)
  const load = async () => {
    setBusy(true)
    setErr('')
    try {
      const c = await calendarDay()
      const events = Array.isArray(c) ? c : c.events ?? []
      setEntries(events.length ? (await planDay(events)).entries : [])
    } catch (e) {
      setErr(String(e))
    }
    setBusy(false)
  }
  useEffect(() => {
    void load()
  }, [])
  return (
    <div>
      <div className="row">
        <button className="btn" onClick={() => file.current?.click()}>Import .ics</button>
        <button className="btn" onClick={load}>Refresh</button>
        <input ref={file} type="file" accept=".ics,text/calendar" hidden onChange={async (e) => {
          const f = e.target.files?.[0]
          if (f) {
            try { await importIcs(f); await load() } catch (x) { setErr(String(x)) }
          }
        }} />
      </div>
      {busy && <p role="status">Loading your day...</p>}
      {err && <p className="err">Could not load the day ({err}). Is the API running? Start it on http://127.0.0.1:8000.</p>}
      {!busy && !err && entries?.length === 0 && <p>No events today. Import an .ics file to plan a day.</p>}
      <ul className="trips">
        {entries?.map((en, i) => (
          <li key={i}>
            <button disabled={!en.trace} onClick={() => en.trace && onShow(en.trace)}>
              <small>{String(en.event.source ?? 'sample')}</small>
              <b>{en.event.title ?? en.event.summary ?? 'Event'}</b>
              <span>{en.event.start ? `starts ${hm(en.event.start)}` : ''}{en.leave_by ? ` · leave by ${hm(en.leave_by)}` : ''}</span>
              <span>{en.needs_place ? 'Needs a place' : en.recommendation ?? ''}</span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  )
}
