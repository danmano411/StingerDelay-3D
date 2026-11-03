import type { TripTrace } from '../api/client'

type Props = {
  trace?: TripTrace | null
}

/**
 * In-app Grok helper stub. Speaks only verified TripTrace numbers (Wave C3).
 * Without XAI_API_KEY, backend returns templates.
 */
export function GrokHelper({ trace }: Props) {
  return (
    <section className="placeholder" aria-label="Grok helper">
      <span className="badge">helper stub</span>
      <p>
        <strong>GrokHelper</strong> — asks leave-by / will-I-make-it questions.
        Answers must pass number verification against{' '}
        <code>allowed_numbers</code>.
      </p>
      <p>
        {trace
          ? `${trace.allowed_numbers.length} allowed number(s) on current trace.`
          : 'Attach a TripTrace before asking.'}
      </p>
    </section>
  )
}
