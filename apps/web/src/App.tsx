import { NavLink, Route, Routes } from 'react-router-dom'
import { Home } from './pages/Home'
import { Plan } from './pages/Plan'
import { Schedule } from './pages/Schedule'

export default function App() {
  return (
    <div className="app-shell">
      <nav className="top-nav" aria-label="Primary">
        <NavLink to="/" className="brand" end>
          Stinger<span>Delay</span>-3D
        </NavLink>
        <ul className="nav-links">
          <li>
            <NavLink to="/" end>
              Home
            </NavLink>
          </li>
          <li>
            <NavLink to="/plan">Plan</NavLink>
          </li>
          <li>
            <NavLink to="/schedule">Schedule</NavLink>
          </li>
        </ul>
      </nav>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/plan" element={<Plan />} />
        <Route path="/schedule" element={<Schedule />} />
      </Routes>
    </div>
  )
}
