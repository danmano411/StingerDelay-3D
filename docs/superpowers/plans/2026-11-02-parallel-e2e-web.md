# StingerDelay-3D Parallel E2E Web Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Parallel rule:** Tasks in the same wave may run concurrently if they own disjoint paths. Never touch `apps/ios/` (iOS agent). Push to `main` after every completed task so the iOS agent can consume contracts immediately.

**Goal:** Ship a complete end-to-end web app (planner → PRT plan card → 3D/replay map → calendar/daily schedule → optional Grok helper) that is lightweight enough for a parallel iOS agent to consume the same APIs.

**Architecture:** Shared FastAPI owns TripTrace numbers. Web is a thin React+TS+Vite client. Delay quantiles come from a Stinger Delay–inspired ETA-decile lookup (replay-first). Solar/materials/energy are product non-goals and must not appear in `apps/web` or user-facing API payloads. Grok only speaks verified numbers.

**Tech Stack:** Python 3.11+ / FastAPI / Pydantic v2; React 18 + TypeScript + Vite; Three.js baseplate in `web-sim/` (stripped for product); IndexedDB for local plans; optional xAI / Google Calendar / X when env keys exist (mock otherwise).

**Spec:** `docs/PRODUCT_VISION.md`, `HANDOFF.md`, `docs/PLAN_UPDATES.md`

## Global Constraints

- Routing engine owns every numeric value; Grok interprets only.
- Every number displayed/spoken must come from `TripTrace` and pass verification.
- Prefer replay mode + simulate-walk for demos.
- Calendar = Google Calendar (next event / classes); mock when no OAuth.
- X / social signals are secondary uncertainty only; always badged.
- No solar panel / PV / materials / energy product UI or KPIs.
- Do not edit `apps/ios/` (owned by iOS agent).
- Keep payloads small and JSON-first for mobile (no megabyte blobs in trip responses).
- Secrets only from env: `XAI_API_KEY`, `GT_BUS_API_KEY`, Google OAuth vars. Never commit secrets.
- Blue route remains flagged synthetic.
- Continuous push to GitHub after each task; note progress in `docs/notes/`.

## Review Focus

- Spoken/displayed numbers that are not in the TripTrace allowed set → must fail verification and fall back to template.
- Far-horizon plans without widened confidence bands → bands must widen with time.
- Social/X factors silently overriding planner → must only widen quantiles and show badge.
- Large campus/replay payloads forced through `/trips/plan` → plan responses stay compact; map assets load separately.
- iOS agent blocked because contracts missing or unstable → OpenAPI + frozen JSON Schema published early and versioned.

## File ownership (disjoint for parallel)

| Owner path | Wave tasks |
|---|---|
| `services/api/contracts/` + OpenAPI | A1 |
| `services/api/` (app, planner, predictor, verify) | A3, B1–B3, C* backend |
| `apps/web/` | A2, B4–B6, C* frontend |
| `scripts/` + `data/normalized/` | A4 |
| `web-sim/` (strip solar chrome only) | A5 |
| `docs/` + `docs/notes/` | All agents append notes; plan updates |
| `apps/ios/` | **FORBIDDEN** for web agent |

---

## Wave A — Foundation (MAX PARALLEL, no cross-deps)

### Task A1: TripTrace + OpenAPI contracts

**Files:**
- Create: `services/api/contracts/trip_trace.py`
- Create: `services/api/contracts/schemas.py`
- Create: `services/api/openapi/openapi.yaml`
- Create: `docs/notes/a1-contracts.txt`
- Test: `services/api/tests/test_contracts.py`

- [ ] Define Pydantic models: `PlanConstraints`, `Leg`, `TripPlan`, `TripTrace`, `Quantiles`, `SocialFactor`
- [ ] Freeze field names used by web + iOS (`p10`/`p50`/`p90`, `p_on_time`, `p_catch`, `explanation_facts`, `allowed_numbers`)
- [ ] Export OpenAPI YAML for iOS agent
- [ ] Write contract unit tests
- [ ] Note + commit + push

### Task A2: Scaffold `apps/web` (Vite React TS)

**Files:**
- Create: `apps/web/` (package.json, vite.config.ts, tsconfig, index.html, src/*)
- Create: `docs/notes/a2-web-scaffold.txt`
- Test: `npm run build` in `apps/web`

- [ ] Vite + React + TS skeleton, GT navy/gold tokens, no Inter-as-only-brand (use existing JetBrains Mono + distinct display)
- [ ] Routes: `/` demo home, `/plan`, `/schedule`
- [ ] API client stub typed against contracts
- [ ] Note + commit + push

### Task A3: Scaffold FastAPI service

**Files:**
- Create: `services/api/main.py`, `requirements.txt`, `README.md`
- Create: `services/api/routers/health.py`, `trips.py`, `calendar.py`, `signals.py`
- Create: `docs/notes/a3-api-scaffold.txt`
- Test: `pytest` health + empty plan 422

- [ ] FastAPI app with CORS for localhost Vite
- [ ] `/health`, stub `/trips/plan`, stub calendar + signals
- [ ] Note + commit + push

### Task A4: Normalize base data (stops, routes, places)

**Files:**
- Create: `scripts/normalize_base.py`
- Create: `data/normalized/routes.json`, `stops.json`, `places.json`
- Create: `docs/notes/a4-normalize.txt`
- Test: script exits 0; stop count > 0; Blue flagged synthetic

- [ ] Parse `data/base/routes.json` → compact stops/routes
- [ ] Seed places (Klaus, Kendeda, Student Center, Midtown MARTA, West Village, Clough)
- [ ] Mark Blue `synthetic: true`
- [ ] Note + commit + push

### Task A5: Strip solar from product path / prepare map baseplate

**Files:**
- Modify: `web-sim/index.html` (remove solar KPIs, Materials, Energy tabs; keep sun for lighting only)
- Create: `docs/notes/a5-strip-solar.txt`
- Create: `apps/web/public/map-embed.html` OR iframe notes pointing at cleaned web-sim
- Test: open map; no solar/materials/energy panes

- [ ] Remove solar product chrome from web-sim
- [ ] Relabel brand to StingerDelay-3D / Buzz Route helper
- [ ] Keep bus replay + buildings + sun lighting
- [ ] Note + commit + push

### Task A6: iOS agent handshake doc

**Files:**
- Create: `docs/IOS_AGENT.md`
- Create: `docs/notes/a6-ios-handshake.txt`

- [ ] Document OpenAPI location, auth, replay mode, forbidden paths
- [ ] Version contracts `v0`
- [ ] Note + commit + push

---

## Wave B — Core product (parallel after Wave A contracts exist)

### Task B1: Delay predictor (ETA-decile lookup + horizon spread)

**Files:**
- Create: `services/api/predictor/lookup.py`
- Create: `data/normalized/delay_lookup.json` (from reference summary patterns)
- Create: `docs/notes/b1-predictor.txt`
- Test: `services/api/tests/test_predictor.py`

- [ ] Implement ETA-bucket delay mean + spread → p10/p50/p90
- [ ] Widen bands with horizon (near <3m tight; ≥60–90m wide)
- [ ] Never invent ML weights; label model `eta_decile_lookup_v0`
- [ ] Note + commit + push

### Task B2: Deterministic planner → TripTrace

**Files:**
- Create: `services/api/planner/graph.py`, `engine.py`, `arrive_by.py`
- Modify: `services/api/routers/trips.py`
- Create: `docs/notes/b2-planner.txt`
- Test: plan Klaus→Kendeda and Student Center→Klaus returns legs + quantiles

- [ ] Walk edges (haversine + walk_speed) + transit edges from normalized stops
- [ ] Monte Carlo sample over ride/wait quantiles → TripTrace
- [ ] Arrive-by binary search for leave-by
- [ ] Prefs: `avoid_stairs` (flag only until elevation graph exists)
- [ ] Note + commit + push

### Task B3: Verification layer

**Files:**
- Create: `services/api/verify/numbers.py`
- Create: `docs/notes/b3-verify.txt`
- Test: reject hallucinated minutes; accept trace numbers

- [ ] Extract numbers from text; compare to `allowed_numbers`
- [ ] Template fallback on failure
- [ ] Note + commit + push

### Task B4: PRT segmented plan card + confidence bands (web)

**Files:**
- Create: `apps/web/src/components/PlanCard.tsx`, `ConfidenceBand.tsx`
- Create: `docs/notes/b4-plan-card.txt`
- Test: Story/demo page renders walk→wait→ride→walk from fixture TripTrace

- [ ] Segmented PRT card with per-leg duration + total ETA + p_on_time
- [ ] Confidence band widens with horizon; far-term copy “check again closer to departure”
- [ ] Note + commit + push

### Task B5: Map shell integration (lightweight)

**Files:**
- Create: `apps/web/src/components/CampusMap.tsx`
- Create: `docs/notes/b5-map.txt`
- Test: map loads; route polyline highlight for chosen plan; no solar UI

- [ ] Embed cleaned web-sim or lightweight canvas/Three shell
- [ ] Draw plan polyline from TripTrace geometry refs (ids only, not full OSM)
- [ ] Mobile-friendly: defer heavy assets; keep main bundle small
- [ ] Note + commit + push

### Task B6: Local path storage (IndexedDB)

**Files:**
- Create: `apps/web/src/storage/plans.ts`
- Create: `docs/notes/b6-storage.txt`
- Test: save/load/delete plan by day key

- [ ] Schema: `{ id, day, label, tripTrace, createdAt }`
- [ ] Mirror JSON schema in `docs/contracts/local_plan_v0.json` for iOS
- [ ] Note + commit + push

---

## Wave C — User flows + Grok helper (parallel stubs → real if keys)

### Task C1: Calendar tool (mock + Google stub)

**Files:**
- Create: `services/api/tools/calendar.py`
- Modify: `services/api/routers/calendar.py`
- Create: `apps/web/src/pages/Schedule.tsx`
- Create: `docs/notes/c1-calendar.txt`
- Test: mock next-event → arrive_by plan

- [ ] `GET /calendar/next` returns next class/event (mock fixtures if no OAuth)
- [ ] Web “when should I leave?” button calls plan with arrive_by
- [ ] Note + commit + push

### Task C2: Daily bus schedule from calendar

**Files:**
- Create: `services/api/planner/day_schedule.py`
- Create: `apps/web/src/components/DaySchedule.tsx`
- Create: `docs/notes/c2-day-schedule.txt`
- Test: 3 mock classes → 3 TripTraces flickable

- [ ] Assign buses from current location + class times
- [ ] Flick/carousel UI
- [ ] Note + commit + push

### Task C3: Grok Voice / helper relay (stub-first)

**Files:**
- Create: `services/api/tools/grok.py`
- Create: `services/api/routers/grok.py`
- Create: `apps/web/src/components/GrokHelper.tsx`
- Create: `docs/notes/c3-grok.txt`
- Test: without `XAI_API_KEY`, template answers using TripTrace; with key, verify numbers

- [ ] In-app text helper first; voice relay hook second
- [ ] All answers pass verification
- [ ] Note + commit + push

### Task C4: Secondary X / social uncertainty

**Files:**
- Create: `services/api/tools/x_signals.py`
- Modify: predictor to accept optional `SocialFactor`
- Create: `docs/notes/c4-x-signals.txt`
- Test: factor widens p90; plan shows “social signal” badge; never changes p50 without badge

- [ ] Mock ingest (game day / high volume)
- [ ] Apply as secondary quantile spread only
- [ ] Note + commit + push

### Task C5: E2E demo wiring + README runbooks

**Files:**
- Modify: root `README.md`, `HANDOFF.md`
- Create: `docs/notes/c5-e2e.txt`, `docs/RUNBOOK_WEB.md`
- Test: scripted curl plan + Vite UI happy path

- [ ] One-command or documented: API + web + map
- [ ] Demo script: leave-now, arrive-by Klaus 8:30, calendar next event, day schedule
- [ ] Note + commit + push

---

## Dependency graph (maximize parallelism)

```
Wave A: A1 ║ A2 ║ A3 ║ A4 ║ A5 ║ A6
              │
Wave B:   B1 ║ B2(needs A1,A4,B1) ║ B3(needs A1) ║ B4(needs A1,A2) ║ B5(needs A2,A5) ║ B6(needs A2)
              │
Wave C:   C1 ║ C2 ║ C3 ║ C4 ║ C5(needs all)
```

Within a wave, launch one subagent per task with disjoint paths. Parent agent merges notes, runs gates, pushes if a subagent cannot.

## Definition of done (web E2E)

1. `uvicorn` serves `/trips/plan` with real TripTrace for campus OD pairs.
2. Web app shows PRT card + confidence bands from that trace.
3. Map shows campus/buses without solar product UI.
4. Mock calendar → leave-by recommendation works offline.
5. Day schedule flick works with mock classes.
6. Grok helper (template or live) only speaks verified numbers.
7. OpenAPI + `docs/IOS_AGENT.md` published for iOS agent.
8. All of the above pushed to GitHub.

## Explicit non-goals (this pass)

- Training new ML models from raw GPS.
- Full OSM walk graph with stairs graph (flag only).
- Production Google OAuth / X app review.
- Any work under `apps/ios/`.
- Solar/PV/energy product features.
