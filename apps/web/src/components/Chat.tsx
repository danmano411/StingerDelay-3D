import { useEffect, useRef, useState } from 'react'
import { chat, status } from '../api/client'
import type { ChatResponse, GrokStatus, Origin } from '../api/types'

type Msg = { role: 'user' | 'bot'; text: string; r?: ChatResponse }
const CHIPS = [
  'I want to make a plan',
  'Get me to Klaus by 8:30',
  "Get me to Klaus by 8:30, and right now it's 6",
  "What's my Monday route?",
  'Walk that path',
  'Plan my day',
]
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const SR = (window as any).SpeechRecognition ?? (window as any).webkitSpeechRecognition
const cid = Math.random().toString(36).slice(2)

const locate = (): Promise<Origin | null> =>
  new Promise((res) => {
    if (!navigator.geolocation) return res(null)
    navigator.geolocation.getCurrentPosition(
      (p) => res({ lat: p.coords.latitude, lon: p.coords.longitude }),
      () => res(null),
      { timeout: 5000, maximumAge: 60000 },
    )
  })

export function Chat({ onResult, onTab, fill }: {
  onResult: (r: ChatResponse) => void
  onTab: (t: 'chat' | 'today') => void
  fill: { text: string; n: number } | null
}) {
  const [msgs, setMsgs] = useState<Msg[]>([])
  const [text, setText] = useState('')
  const [busy, setBusy] = useState(false)
  const [interim, setInterim] = useState('')
  const [listening, setListening] = useState(false)
  const [st, setSt] = useState<GrokStatus | null>(null)
  const [offline, setOffline] = useState(false)
  const [start, setStart] = useState<'unknown' | 'gps' | 'default'>('unknown')
  const origin = useRef<Origin | null>(null)
  const end = useRef<HTMLDivElement>(null)
  const area = useRef<HTMLTextAreaElement>(null)
  useEffect(() => {
    status().then(setSt).catch(() => setOffline(true))
  }, [])
  useEffect(() => end.current?.scrollIntoView?.({ block: 'end' }), [msgs, interim])
  useEffect(() => {
    if (fill) {
      setText(fill.text)
      area.current?.focus()
    }
  }, [fill])

  const send = async (m: string) => {
    m = m.trim()
    if (!m || busy) return
    if (/plan my day|monday route/i.test(m)) onTab('today')
    setMsgs((x) => [...x, { role: 'user', text: m }])
    setText('')
    setBusy(true)
    try {
      const r = await chat(cid, m, origin.current)
      setOffline(false)
      setMsgs((x) => [...x, { role: 'bot', text: r.reply, r }])
      onResult(r)
    } catch {
      setOffline(true)
      setMsgs((x) => [...x, { role: 'bot', text: 'Could not reach the API.' }])
    }
    setBusy(false)
  }
  const talk = async () => {
    if (listening) return
    setListening(true)
    setInterim('Finding your location...')
    origin.current = await locate()
    setStart(origin.current ? 'gps' : 'default')
    if (!SR) {
      setListening(false)
      setInterim('')
      area.current?.focus()
      return
    }
    const rec = new SR()
    rec.interimResults = true
    rec.lang = 'en-US'
    let final = ''
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    rec.onresult = (e: any) => {
      let i = ''
      for (const res of e.results) {
        if (res.isFinal) final += res[0].transcript
        else i += res[0].transcript
      }
      setInterim(final + i)
    }
    rec.onend = () => {
      setListening(false)
      setInterim('')
      if (final) void send(final)
    }
    rec.onerror = () => {
      setListening(false)
      setInterim('')
    }
    rec.start()
    setInterim('Listening...')
  }
  const line = offline ? 'API offline.' : !st ? 'Checking assistant...' : st.key_valid ? 'Grok active' : 'Grok key not active: using local parser'
  const from = start === 'gps' ? 'Starting from: your current location' : start === 'default' ? 'Starting from: default start point (location unavailable or denied)' : 'Starting from: default start point until you share location'
  return (
    <div className="chat">
      <p className="status">{line}</p>
      {offline && <p className="err">Start the API: run the services/api server on http://127.0.0.1:8000, then try again.</p>}
      <div className={`micwrap ${msgs.length ? 'compact' : ''}`}>
        <button type="button" className={`mic ${listening ? 'on' : ''}`} onClick={talk} aria-pressed={listening} aria-label="Tap to talk">
          <svg viewBox="0 0 24 24" width="32" height="32" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
            <rect x="9" y="3" width="6" height="12" rx="3" />
            <path d="M5 11a7 7 0 0 0 14 0M12 18v3" />
          </svg>
          <span>{listening ? 'Listening' : 'Tap to talk'}</span>
        </button>
        <p className="from" aria-live="polite">{from}</p>
        {!SR && <p className="from">Voice recognition is not supported in this browser. Type below.</p>}
        {interim && <p className="interim" aria-live="polite">{interim}</p>}
      </div>
      <div className="msgs" aria-live="polite">
        {msgs.length === 0 && (
          <div className="chips">{CHIPS.map((c) => <button key={c} className="chip-btn" onClick={() => send(c)}>{c}</button>)}</div>
        )}
        {msgs.map((m, i) => (
          <div key={i} className={`msg ${m.role}`}>
            <p>{m.text}</p>
            {m.r && <small className="badge">{m.r.source === 'grok' ? 'Grok' : 'Local parser'}, {m.r.verified ? 'verified' : 'template'}</small>}
            {m.r?.clarification && (
              <div className="chips">
                <p>{m.r.clarification.question}</p>
                {m.r.clarification.options.map((o) => <button key={o} className="chip-btn" onClick={() => send(o)}>{o}</button>)}
              </div>
            )}
          </div>
        ))}
        {busy && <div className="msg bot"><p>Thinking...</p></div>}
        <div ref={end} />
      </div>
      <form onSubmit={(e) => { e.preventDefault(); void send(text) }}>
        <textarea ref={area} rows={2} value={text} onChange={(e) => setText(e.target.value)} aria-label="Message"
          placeholder="Where do you want to go, and by when?"
          onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); void send(text) } }} />
        <div className="row"><button className="btn gold" type="submit" disabled={busy}>Send</button></div>
      </form>
    </div>
  )
}
