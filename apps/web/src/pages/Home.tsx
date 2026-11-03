import { Link } from 'react-router-dom'
import { CampusMap } from '../components/CampusMap'
import { GrokHelper } from '../components/GrokHelper'
import { PlanCard } from '../components/PlanCard'

export function Home() {
  return (
    <div className="page">
      <header>
        <h1>Buzz Route helper</h1>
        <p className="lede">
          Plan a campus trip with Stinger Delay quantiles, see a PRT-style card,
          and ask Grok only about verified numbers. Demo home for Wave A
          scaffold — wire live API in later waves.
        </p>
      </header>
      <p>
        Go to <Link to="/plan">Plan</Link> or{' '}
        <Link to="/schedule">Schedule</Link>.
      </p>
      <PlanCard />
      <CampusMap />
      <GrokHelper />
    </div>
  )
}
