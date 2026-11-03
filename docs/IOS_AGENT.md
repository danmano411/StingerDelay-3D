# iOS agent handshake

**Owner of this doc:** web / shared agent  
**Owner of `apps/ios/`:** iOS agent only — web agent will not touch it.  
**Contract version:** `v0` — breaking changes bump to `v1` and are noted in `docs/notes/EXECUTION_LEDGER.txt`.

## What you can consume now / soon

| Artifact | Path | Status |
|---|---|---|
| OpenAPI | `services/api/openapi/openapi.yaml` | Wave A1 |
| TripTrace models | `services/api/contracts/` | Wave A1 |
| Local plan schema | `docs/contracts/local_plan_v0.json` | Wave A6 (this doc) |
| Normalized stops/routes | `data/normalized/` | Wave A4 |
| Planner | `POST /trips/plan` | Wave B2 |
| Calendar (mock/live) | `GET /calendar/next` | Wave C1 |
| Social factor (secondary) | `GET /signals/x` | Wave C4 |
| Health | `GET /health` | Wave A3 |

## Forbidden paths (do not write)

| Path | Why |
|---|---|
| `apps/web/` | Web agent only |
| `web-sim/` | Map baseplate; web strip/embed only |
| `services/api/` implementation | Shared backend — consume via OpenAPI; do not fork logic into iOS |
| Secrets in repo | Never commit keys; env only |

iOS may **read** OpenAPI, normalized JSON, and this handshake. iOS owns **write** access only under `apps/ios/`.

## Environment variables

Clients and local API expect these from the environment (never from committed files):

| Variable | Who needs it | Purpose |
|---|---|---|
| `API_BASE_URL` | iOS / web clients | Base URL, e.g. `http://127.0.0.1:8000` |
| `XAI_API_KEY` | API server only | Grok helper; mock/template when missing |
| `GT_BUS_API_KEY` | API server only | Live bus scrapes; prefer **replay** without it |
| Google OAuth vars (C1+) | API server only | Calendar; mock fixtures when missing |

iOS should never embed `XAI_API_KEY` or `GT_BUS_API_KEY`. Talk to the shared API; secrets stay server-side.

Optional client knobs (document in your app config, not in git secrets):

| Variable | Default | Purpose |
|---|---|---|
| `REPLAY_MODE` | `true` for demos | Prefer frozen / replay buses over live |
| `SIMULATE_WALK` | `true` for demos | Drive map from plan geometry refs, not live GPS |

## curl examples (local API)

Assume the FastAPI scaffold is listening on `http://127.0.0.1:8000` after Wave A3.

### Health

```bash
curl -sS "$API_BASE_URL/health"
# expect JSON like: {"status":"ok"} or similar v0 health body
```

### Plan a trip (stub until B2; real TripTrace after B2)

```bash
curl -sS -X POST "$API_BASE_URL/trips/plan" \
  -H "Content-Type: application/json" \
  -d '{
    "origin": "klaus",
    "destination": "kendeda",
    "depart_at": null,
    "arrive_by": null,
    "prefs": {
      "avoid_stairs": false,
      "walk_speed_mps": 1.4
    },
    "replay": true
  }'
```

Arrive-by leave recommendation (calendar-driven flows):

```bash
curl -sS -X POST "$API_BASE_URL/trips/plan" \
  -H "Content-Type: application/json" \
  -d '{
    "origin": "student_center",
    "destination": "klaus",
    "arrive_by": "2026-11-03T08:30:00-05:00",
    "prefs": { "avoid_stairs": true },
    "replay": true
  }'
```

### Calendar next event (mock until OAuth)

```bash
curl -sS "$API_BASE_URL/calendar/next"
```

### Social / X factor (secondary only)

```bash
curl -sS "$API_BASE_URL/signals/x?place=klaus"
```

Treat any factor as **uncertainty widening** only. Badge it in UI. Never treat it as a primary ETA.

## Payload guidance

1. **Numbers:** Every minute, probability, or distance shown or spoken must come from `TripTrace` (`p10` / `p50` / `p90`, `p_on_time`, `p_catch`, leg durations, `allowed_numbers`). Run verification before speech.
2. **Keep responses small:** Do not request or embed `web-sim/data.js`, full campus meshes, or megabyte replay blobs through `/trips/plan`. Load map assets separately (`data/normalized/`, MapKit overlays, or a dedicated static host).
3. **Geometry refs, not full OSM:** Prefer stop/route **ids** and short polyline refs from the plan; resolve geometry client-side from normalized data.
4. **Blue route:** Always flag synthetic when present (`synthetic: true` on Blue).
5. **Social:** Optional; widens quantiles only; always badged.
6. **Local saves:** Persist with `docs/contracts/local_plan_v0.json` — see below.

### `TripTrace` fields iOS should expect (v0)

Frozen by Wave A1 OpenAPI. At minimum:

- Chosen plan + optional alternatives  
- Legs: walk / wait / ride (and optional transfer)  
- Quantiles: `p10`, `p50`, `p90`  
- `p_on_time`, `p_catch`  
- `explanation_facts`, `allowed_numbers`  
- Optional `social_factor` (secondary)

Do not invent numeric fields client-side.

## Local saved plans (`local_plan_v0`)

Schema file: [`docs/contracts/local_plan_v0.json`](contracts/local_plan_v0.json)

Minimal shape:

```json
{
  "id": "uuid-or-stable-key",
  "day": "2026-11-03",
  "label": "Klaus 08:30",
  "tripTrace": { },
  "createdAt": "2026-11-02T20:00:00Z"
}
```

Store offline (Core Data / file / UserDefaults for small payloads). Key by `day` for schedule flick-through. Schema is shared with web IndexedDB (Wave B6).

## Replay + simulate-walk notes

Prefer these for demos and CI:

1. Set `"replay": true` on plan requests (or rely on server default when `GT_BUS_API_KEY` is absent).
2. Drive the map from the returned plan’s geometry refs + `data/normalized/` — do not require live GPS for a first demo.
3. Simulate-walk: animate along walk legs using plan durations; do not invent new ETAs while animating.
4. Far-horizon plans: expect wider `p10`–`p90` bands and copy that suggests checking again closer to departure — do not tighten bands on the client.
5. Without live keys, calendar and X endpoints should return **mocks**; label UI accordingly if the API marks them.

## Rules that bind both agents

1. Every number shown or spoken comes from `TripTrace` and passes verification.
2. Social / X signals only widen uncertainty and must be badged.
3. No solar / PV / materials / energy product surfaces.
4. Prefer replay + simulate-walk demos.
5. Keep payloads small — do not pull `web-sim/data.js` through the planner API.
6. Blue route is synthetic.

## Suggested iOS parallel track (while web builds)

You may start immediately on:

1. Xcode project under `apps/ios/` consuming frozen OpenAPI once A1 lands.
2. Native map shell (MapKit) using `data/normalized/stops.json` + route polylines.
3. Local plan storage matching `local_plan_v0.json`.
4. Calendar + location permissions UI (mock planner until B2).

Pull `main` frequently; web agent pushes after every task.

## Auth note (v0)

v0 local demos are **unauthenticated** against the FastAPI process on localhost. Do not send bearer tokens unless a later contract version adds auth. Production auth is out of scope for Wave A.
