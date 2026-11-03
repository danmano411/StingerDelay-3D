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
  const onResult = (r: ChatResponse) => {
    if (r.trace) show(r.trace)
    if (r.action === 'walk') walk()
    if (r.action === 'stop_walk') stop()
  }
  return (
    <div className="app">
      <Sim ref={sim} onProgress={setProg} onDone={() => { setWalking(false); setArrived(true) }} />
      <aside className={`panel ${open ? 'open' : ''}`}>
        <button className="grab" onClick={() => setOpen(!open)} aria-expanded={open}>StingerDelay-3D</button>
        <div className="tabs" role="tablist">
          {(['chat', 'today'] as const).map((k) => (
            <button key={k} role="tab" aria-selected={tab === k} onClick={() => setTab(k)}>{k === 'chat' ? 'Assistant' : 'Today'}</button>
          ))}
        </div>
        <div className="body">
          {trace && <PlanCard trace={trace} walking={walking} progress={prog} arrived={arrived} onWalk={walk} onStop={stop} />}
          {tab === 'chat' ? <Chat onResult={onResult} onTab={setTab} /> : <Today onShow={(t) => { show(t); setTab('chat') }} />}
        </div>
      </aside>
    </div>
  )
}
