import { useEffect, useRef, useState } from 'react'
import { chat, status } from '../api/client'
import type { ChatResponse, GrokStatus } from '../api/types'

type Msg = { role: 'user' | 'bot'; text: string; r?: ChatResponse }
const CHIPS = ['I want to make a plan', 'Get me to Klaus by 8:30', 'Walk that path', 'Plan my day']
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const SR = (window as any).SpeechRecognition ?? (window as any).webkitSpeechRecognition
const cid = Math.random().toString(36).slice(2)

export function Chat({ onResult, onTab }: { onResult: (r: ChatResponse) => void; onTab: (t: 'chat' | 'today') => void }) {
  const [msgs, setMsgs] = useState<Msg[]>([])
  const [text, setText] = useState('')
  const [busy, setBusy] = useState(false)
  const [interim, setInterim] = useState('')
  const [st, setSt] = useState<GrokStatus | null>(null)
  const [offline, setOffline] = useState(false)
  const end = useRef<HTMLDivElement>(null)
  useEffect(() => {
    status().then(setSt).catch(() => setOffline(true))
  }, [])
  useEffect(() => end.current?.scrollIntoView?.({ block: 'end' }), [msgs, interim])

  const send = async (m: string) => {
    m = m.trim()
    if (!m || busy) return
    if (/plan my day/i.test(m)) onTab('today')
    setMsgs((x) => [...x, { role: 'user', text: m }])
    setText('')
    setBusy(true)
    try {
      const r = await chat(cid, m)
      setOffline(false)
      setMsgs((x) => [...x, { role: 'bot', text: r.reply, r }])
      onResult(r)
    } catch {
      setOffline(true)
      setMsgs((x) => [...x, { role: 'bot', text: 'Could not reach the API.' }])
    }
    setBusy(false)
  }
  const listen = () => {
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
      setInterim('')
      if (final) void send(final)
    }
    rec.onerror = () => setInterim('')
    rec.start()
    setInterim('Listening...')
  }
  const line = offline ? 'API offline.' : !st ? 'Checking assistant...' : st.key_valid ? 'Grok active' : 'Grok key not active: using local parser'
  return (
    <div>
      <p className="status">{line}</p>
      {offline && <p className="err">Start the API: run the services/api server on http://127.0.0.1:8000.</p>}
      <div className="msgs" aria-live="polite">
        {msgs.length === 0 && (
          <div className="chips">{CHIPS.map((c) => <button key={c} className="chip-btn" onClick={() => send(c)}>{c}</button>)}</div>
        )}
        {msgs.map((m, i) => (
          <div key={i} className={`msg ${m.role}`}>
            <p>{m.text}</p>
            {m.r && <small className="badge">{m.r.source === 'grok' ? 'Grok' : 'Local parser'} · {m.r.verified ? 'verified' : 'template'}</small>}
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
        <textarea rows={2} value={interim || text} onChange={(e) => setText(e.target.value)} aria-label="Message"
          placeholder="Where do you want to go, and by when?"
          onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); void send(text) } }} />
        <div className="row">
          {SR ? <button type="button" className="btn" onClick={listen} aria-label="Speak">Mic</button> : <small>Voice input is not supported in this browser; type instead.</small>}
          <button className="btn gold" type="submit" disabled={busy}>Send</button>
        </div>
      </form>
    </div>
  )
}
