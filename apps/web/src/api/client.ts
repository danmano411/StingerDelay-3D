/** TripTrace-shaped types (v0) — mirror services/api contracts when available. */

export type Quantiles = {
  p10: number
  p50: number
  p90: number
}

export type SocialFactor = {
  source: string
  label: string
  spread_minutes: number
  badge: boolean
}

export type LegKind = 'walk' | 'wait' | 'ride' | 'transfer'

export type Leg = {
  kind: LegKind
  from_id: string
  to_id: string
  route_id?: string
  duration_s: number
  quantiles?: Quantiles
  geometry_ref?: string
  synthetic?: boolean
}

export type PlanConstraints = {
  origin_id: string
  destination_id: string
  depart_at?: string
  arrive_by?: string
  avoid_stairs?: boolean
  include_social?: boolean
}

export type TripPlan = {
  legs: Leg[]
  total_duration_s: number
  quantiles: Quantiles
  p_on_time: number
  p_catch?: number
}

export type TripTrace = {
  plan_id: string
  model: string
  plan: TripPlan
  explanation_facts: string[]
  allowed_numbers: number[]
  social_factor?: SocialFactor
  horizon_minutes?: number
}

const API_BASE = import.meta.env.VITE_API_BASE ?? 'http://localhost:8000'

export async function fetchPlan(constraints: PlanConstraints): Promise<TripTrace> {
  const res = await fetch(`${API_BASE}/trips/plan`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify(constraints),
  })
  if (!res.ok) {
    const detail = await res.text().catch(() => res.statusText)
    throw new Error(`plan failed (${res.status}): ${detail}`)
  }
  return (await res.json()) as TripTrace
}
