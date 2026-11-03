type Props = {
  planId?: string
}

/** Lightweight map shell — no three.js in A2; Wave B5 embeds cleaned web-sim. */
export function CampusMap({ planId }: Props) {
  return (
    <section className="placeholder" aria-label="Campus map">
      <span className="badge">map shell</span>
      <p>
        <strong>CampusMap</strong> — campus / bus replay surface (no solar UI).
        Heavy assets deferred; polyline from TripTrace geometry refs later.
      </p>
      <p>{planId ? <>Highlighting plan <code>{planId}</code></> : 'No route selected.'}</p>
    </section>
  )
}
