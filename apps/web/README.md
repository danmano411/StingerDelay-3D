# StingerDelay-3D — web

Lightweight Vite + React 18 + TypeScript client for the campus trip planner.
Consumes the FastAPI TripTrace API. No three.js in this scaffold (map embed later).

## Scripts

| Command | What it does |
|---|---|
| `npm install` | Install dependencies |
| `npm run dev` | Vite dev server (http://localhost:5173) |
| `npm run build` | Typecheck + production build → `dist/` |
| `npm preview` | Serve the production build locally |

## API

Set `VITE_API_BASE` if the planner is not on `http://localhost:8000`.
`src/api/client.ts` posts to `/trips/plan` and types responses as `TripTrace`.

## Brand

GT navy `#003057`, gold `#EAAA00`, tech gold `#B3A369`. Display: Fraunces. Mono: JetBrains Mono. No solar/PV product UI.
