import { useState } from 'react'
import { fetchPlan, type TripTrace } from '../api/client'
import { CampusMap } from '../components/CampusMap'
import { GrokHelper } from '../components/GrokHelper'
import { PlanCard } from '../components/PlanCard'

export function Plan() {
  const [trace, setTrace] = useState<TripTrace | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function onPlan() {
    setBusy(true)
    setError(null)
    try {
      const next = await fetchPlan({
        origin_id: 'klaus',
        destination_id: 'kendeda',
      })
      setTrace(next)
    } catch (e) {
      setTrace(null)
      setError(e instanceof Error ? e.message : String(e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="page">
      <header>
        <h1>Plan a trip</h1>
        <p className="lede">
          POST stub to <code>http://localhost:8000/trips/plan</code>. Numbers
          come only from TripTrace.
        </p>
      </header>
      <p>
        <button type="button" onClick={onPlan} disabled={busy}>
          {busy ? 'Planning…' : 'Plan Klaus → Kendeda'}
        </button>
      </p>
      {error ? <p role="alert">{error}</p> : null}
      <PlanCard trace={trace} />
      <CampusMap planId={trace?.plan_id} />
      <GrokHelper trace={trace} />
    </div>
  )
}
