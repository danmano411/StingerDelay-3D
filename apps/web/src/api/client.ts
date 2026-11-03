import type { CalEvent, ChatResponse, DayEntry, GrokStatus } from './types'

export const API = (import.meta.env.VITE_API_BASE as string | undefined) ?? 'http://127.0.0.1:8000'

async function j<T>(path: string, init?: RequestInit): Promise<T> {
  const r = await fetch(API + path, init)
  if (!r.ok) throw new Error(`${path} ${r.status}`)
  return r.json() as Promise<T>
}
const post = (body: unknown): RequestInit => ({
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
})

export const chat = (conversation_id: string, message: string, origin?: { lat: number; lon: number } | null) =>
  j<ChatResponse>('/grok/chat', post(origin ? { conversation_id, message, origin } : { conversation_id, message }))
export const status = () => j<GrokStatus>('/grok/status')
export const calendarDay = () => j<{ events?: CalEvent[]; source?: string } | CalEvent[]>('/calendar/day')
export const planDay = (events: CalEvent[]) => j<{ entries: DayEntry[] }>('/day/plan', post({ events: events.map((e) => ({ ...e, place: e.place ?? e.location })) }))
export const importIcs = (file: File) => {
  const f = new FormData()
  f.append('file', file)
  return j<unknown>('/calendar/import', { method: 'POST', body: f })
}
export const routesWeek = () => j<import('./types').WeekResponse>('/routes/week')
