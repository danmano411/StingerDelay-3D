import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from 'react'
import { API } from '../api/client'
import type { TripTrace } from '../api/types'

export type Progress = { leg_index: number; leg_kind: string; fraction: number }
export type SimHandle = { send: (m: { type: string; trace?: TripTrace }) => void }

export const Sim = forwardRef<SimHandle, { onProgress: (p: Progress) => void; onDone: () => void }>(
  ({ onProgress, onDone }, ref) => {
    const frame = useRef<HTMLIFrameElement>(null)
    const ready = useRef(false)
    const queue = useRef<object[]>([])
    const [state, setState] = useState<'loading' | 'ready' | 'failed'>('loading')
    const cb = useRef({ onProgress, onDone })
    cb.current = { onProgress, onDone }

    useImperativeHandle(ref, () => ({
      send: (m) => {
        if (ready.current) frame.current?.contentWindow?.postMessage(m, '*')
        else queue.current.push(m)
      },
    }))
    useEffect(() => {
      const h = (e: MessageEvent) => {
        if (e.source !== frame.current?.contentWindow) return
        const d = e.data ?? {}
        if (d.type === 'sim.ready') {
          ready.current = true
          setState('ready')
          queue.current.splice(0).forEach((m) => frame.current?.contentWindow?.postMessage(m, '*'))
        } else if (d.type === 'walk.progress') cb.current.onProgress(d)
        else if (d.type === 'walk.done') cb.current.onDone()
      }
      window.addEventListener('message', h)
      const t = setTimeout(() => !ready.current && setState('failed'), 20000)
      return () => {
        window.removeEventListener('message', h)
        clearTimeout(t)
      }
    }, [])
    return (
      <div className="sim">
        <iframe ref={frame} title="3D campus view" src={`${API}/sim/index.html?embed=1`} />
        {state !== 'ready' && (
          <div className="sim-msg" role="status">
            {state === 'loading' ? 'Loading 3D view...' : '3D view unavailable. Start the API on port 8000; the panel still works.'}
          </div>
        )}
      </div>
    )
  },
)
