export type Leg = {
  kind: 'walk' | 'wait' | 'ride' | 'transfer_walk'
  duration_s_p50: number
  label: string
  route_id?: string | null
  path?: [number, number][]
  distance_m?: number
  estimate?: boolean
  synthetic?: boolean
}
export type TripTrace = {
  plan: {
    mode: string
    legs: Leg[]
    total_s: { p10: number; p50: number; p90: number }
    leave_at: string
    arrive_at: string
    p_on_time?: number | null
    p_catch?: number | null
    explanation_facts?: unknown[]
  }
  alternatives?: unknown[]
  status?: string
  origin_name?: string
  destination_name?: string
  model_id?: string
  confidence_horizon_s?: number
  social_factor?: unknown
}
export type ChatResponse = {
  conversation_id: string
  reply: string
  source: 'grok' | 'local'
  verified: boolean
  action: 'show_path' | 'walk' | 'stop_walk' | null
  trace: TripTrace | null
  clarification: { question: string; options: string[] } | null
  events?: unknown[]
}
export type GrokStatus = { provider: string; key_present: boolean; key_valid: boolean; detail: string }
export type CalEvent = { title?: string; summary?: string; start?: string; location?: string; source?: string; [k: string]: unknown }
export type DayEntry = { event: CalEvent; trace: TripTrace | null; needs_place?: boolean; recommendation?: string; leave_by?: string }
export type Origin = { lat: number; lon: number }
export type WeekResponse = { source?: string; days: Record<string, DayEntry[]> }
