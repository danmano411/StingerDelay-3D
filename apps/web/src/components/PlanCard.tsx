import type { TripTrace } from '../api/client'

type Props = {
  trace?: TripTrace | null
}

/** Placeholder PRT segmented plan card — filled in Wave B. */
export function PlanCard({ trace }: Props) {
  return (
    <section className="placeholder" aria-label="Plan card">
      <span className="badge">placeholder</span>
      <p>
        <strong>PlanCard</strong> — segmented walk → wait → ride → walk with
        p10/p50/p90 confidence bands (Wave B4).
      </p>
      {trace ? (
        <p>
          Loaded plan <code>{trace.plan_id}</code> · model{' '}
          <code>{trace.model}</code> · p50{' '}
          {Math.round(trace.plan.quantiles.p50)}s
        </p>
      ) : (
        <p>No TripTrace yet. Call <code>fetchPlan</code> from /plan.</p>
      )}
    </section>
  )
}
