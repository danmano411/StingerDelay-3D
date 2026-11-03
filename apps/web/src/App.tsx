import { useRef, useState } from 'react'
import { PlanCard } from './components/PlanCard'
import { Sim, type Progress, type SimHandle } from './components/Sim'
import { Chat } from './components/Chat'
import { Today } from './components/Today'
import type { ChatResponse, TripTrace } from './api/types'

export default function App() {
  const sim = useRef<SimHandle>(null)
  const [tab, setTab] = useState<'chat' | 'today'>('chat')
  const [trace, setTrace] = useState<TripTrace | null>(null)
  const [walking, setWalking] = useState(false)
  const [arrived, setArrived] = useState(false)
  const [prog, setProg] = useState<Progress | null>(null)
  const [open, setOpen] = useState(true)
  const [fill, setFill] = useState<{ text: string; n: number } | null>(null)
  const [session, setSession] = useState(0)
  const [started, setStarted] = useState(false)
  const current = useRef(0)
  current.current = session

  const show = (t: TripTrace) => {
    setTrace(t)
    setArrived(false)
    setProg(null)
    sim.current?.send({ type: 'plan.show', trace: t })
  }
  const walk = () => {
    setWalking(true)
    setArrived(false)
    sim.current?.send({ type: 'walk.start' })
  }
  const stop = () => {
    setWalking(false)
    sim.current?.send({ type: 'walk.stop' })
  }
  const back = () => {
    setWalking(false)
    setArrived(false)
    setProg(null)
    setTrace(null)
    setStarted(false)
    setFill(null)
    setTab('chat')
    setSession((n) => n + 1)
    sim.current?.send({ type: 'plan.clear' })
  }
  const onResult = (r: ChatResponse, from: number) => {
    if (from !== current.current) return // answer arrived after Back was pressed
    if (r.trace) show(r.trace)
    if (r.action === 'walk') walk()
    if (r.action === 'stop_walk') stop()
  }
  return (
    <div className="app">
      <Sim ref={sim} onPick={(name) => { setTab('chat'); setOpen(true); setFill({ text: `Get me to ${name}`, n: Date.now() }) }} onProgress={setProg} onDone={() => { setWalking(false); setArrived(true) }} />
      <aside className={`panel ${open ? 'open' : ''}`}>
        <div className="head">
          {(started || trace || tab !== 'chat') && <button className="back" onClick={back}><span aria-hidden="true">&larr;</span> Back</button>}
          <button className="grab" onClick={() => setOpen(!open)} aria-expanded={open}>Buzz Route</button>
        </div>
        <div className="tabs" role="tablist">
          {(['chat', 'today'] as const).map((k) => (
            <button key={k} role="tab" aria-selected={tab === k} onClick={() => setTab(k)}>{k === 'chat' ? 'Assistant' : 'Today'}</button>
          ))}
        </div>
        <div className="body">
          {trace && <PlanCard trace={trace} walking={walking} progress={prog} arrived={arrived} onWalk={walk} onStop={stop} />}
          {tab === 'chat' ? <Chat key={session} onResult={(r) => onResult(r, session)} onStart={() => setStarted(true)} onTab={setTab} fill={fill} /> : <Today onShow={(t) => { show(t); setStarted(true); setTab('chat') }} />}
        </div>
      </aside>
    </div>
  )
}
