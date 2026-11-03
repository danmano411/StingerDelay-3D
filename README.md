# StingerDelay-3D

Voice-first, 3D multimodal navigation for Georgia Tech (walk + Stinger buses + Grok).

**Repo:** https://github.com/danmano411/StingerDelay-3D  
**Handoff for agents:** [`HANDOFF.md`](HANDOFF.md)  
**Product vision:** [`docs/PRODUCT_VISION.md`](docs/PRODUCT_VISION.md)  

## Run locally

Prerequisites: Python 3.10+ and Node.js 18+ with npm. Run the API and web client in separate terminals, starting from the repository root.

```bash
# Terminal 1: API + embedded 3D simulation
cd services/api
python3 -m venv .venv
source .venv/bin/activate
# Windows: .venv\Scripts\activate
python -m pip install -r requirements.txt fastapi uvicorn requests python-multipart httpx
python -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

```bash
# Terminal 2: React web client
cd apps/web
npm install
npm run dev
```

Open http://localhost:5173. API documentation is at http://127.0.0.1:8000/docs, and the API serves the 3D scene at http://127.0.0.1:8000/sim/index.html; a separate static server is optional. Vite proxies `/sim` to keep the embedded scene on the web client's origin. Set `VITE_API_BASE` in `apps/web/.env.local` if the API uses another address, then restart Vite.

Try **“Get me to Klaus”**, **“walk that path”**, and **“What's my Monday route?”**. The Today tab shows the sample schedule and weekday routes. The Back button clears the current trip and starts a fresh assistant session.

## Current implementation and demo data

| Area | Current behavior |
|---|---|
| Planner | Compares walking and bus trips; returns `TripTrace` legs, p10/p50/p90 durations, on-time probability, and alternatives. Arrive-by planning targets 90% on-time probability. |
| Bus timing | The scene replays recorded GPS; Blue buses are synthetic. Planner waits use route loop/headway estimates and an ETA-bucket uncertainty lookup, rather than a live arrival feed or a loaded trained model. |
| 3D navigation | Displays planned paths and an animated walker. Buses and the walker share a 5× demo clock; road-following walk geometry is for display and does not recalculate planner timings. |
| Assistant and voice | Optional xAI tool calling with a local parser fallback. Browser speech recognition depends on browser support; `/grok/transcribe` is a separate key-dependent transcription endpoint. |
| Calendar | Sample weekday schedules and API-based `.ics` import. Google Calendar OAuth is not implemented; adding Google credentials alone does not connect an account. See the [API README](services/api/README.md) for the current import format. |
| X signals | `/signals/x` returns a neutral stub. `/signals/x/feed` can request cited posts with an xAI key; this feed is not connected to planner uncertainty. |
| iOS | Native client consumes `/trips/plan` and `/grok/chat`, with an offline routing fallback. See [iOS setup](apps/ios/README.md). |

The planner and local assistant work without an xAI key; the 3D scene uses the bundled Three.js files under `web-sim/vendor/three/`. For optional xAI features, set `XAI_API_KEY` in the repository-root `.env` or the server environment. `GROK_TEXT_MODEL` overrides the configured text model. Check `/grok/status` for key status and `/calendar/status` for the active calendar source. Do not commit credentials.

## Hierarchy & ownership (read this first)

This repo is shared by multiple Grok agents. Keep work separated so agents do not overwrite each other.

| Path | Owner / purpose | Notes |
|---|---|---|
| `README.md` | Shared | High-level overview and this hierarchy. Update carefully. |
| `HANDOFF.md` | Shared | Full context handoff for Cursor and other agents. |
| `docs/` | Shared planning | Vision, plan updates, inventory, open questions. |
| `apps/web/` | Web Grok (this agent / future) | React + TypeScript web app (current focus). |
| `apps/ios/` | iOS Grok (separate agent) | Native iOS app. **Do not touch unless you are the iOS agent.** |
| `services/api/` | Shared backend | FastAPI routing engine, predictor, Grok tools, verification. |
| `data/` | Shared | Normalized data, graphs, models, replays. |
| `scripts/` | Shared | Inventory, normalize, build graphs, train, eval. |

**Rules for all agents:**
- The routing engine owns every numeric value (times, distances, probabilities). Grok only interprets, speaks, and explains.
- Every number shown or spoken must come from a `TripTrace` and pass verification.
- Prefer replay mode + simulate-walk for demos.
- Calendar integration is limited to Google Calendar (next event / classes) for now.
- X / social signals are **secondary** uncertainty inputs only (game days, crowds). Never primary.

## Current plan (high level)

See `docs/PRODUCT_VISION.md` and `HANDOFF.md` for the full executable breakdown.

**Start here, 20-minute build:** [`docs/plans/00-INDEX.md`](docs/plans/00-INDEX.md)  
**Full spec:** [`docs/spec/BUZZ_ROUTE_SPEC.md`](docs/spec/BUZZ_ROUTE_SPEC.md)  
**Earlier task detail:** [`docs/superpowers/plans/2026-11-02-parallel-e2e-web.md`](docs/superpowers/plans/2026-11-02-parallel-e2e-web.md)  
**Ledger:** [`docs/notes/EXECUTION_LEDGER.txt`](docs/notes/EXECUTION_LEDGER.txt)  
**iOS handshake:** [`docs/IOS_AGENT.md`](docs/IOS_AGENT.md)

1. Deterministic planner (walk + transit + Monte Carlo quantiles from Stinger Delay).
2. PRT-style segmented plan card + confidence bands that widen with time horizon.
3. In-app Grok Bot helper (Voice + Calendar): personal daily bus schedule from classes.
4. Secondary X signal layer (crowds / events → extra uncertainty).
5. Full session, re-planning, verification, explainability.
6. Separate iOS agent consumes the same backend APIs.

**Product non-goals:** solar/PV/materials/energy UI in the shipping app.

## Related

- Stinger Delay source: https://github.com/gt-big-data/stinger-delay
- Crowd reference: https://waitz.io/gatech
