# Buzz Route — Full Rebuild Spec

> A voice-first, 3D, live navigation app for Georgia Tech that combines walking paths, the Stinger buses, and Grok.
> Spec version 1.0, 2026-11-02. "Buzz Route" is a placeholder name.

## What this folder is

This folder, together with the project data zip, is everything needed to rebuild the system **from scratch**. It is written for a human team and for a coding agent (Cursor, Grok Bot, etc.).

| File | Contents |
|---|---|
| `00-README.md` | This file: reading order, ground rules, glossary, rebuild order |
| `01-product-spec.md` | Problem, users, features, scope, success criteria |
| `02-architecture.md` | System components, data flow, tech stack, repo layout, configuration |
| `03-data-contracts.md` | How to inventory the zip, the normalized data schemas, georeferencing the sim world |
| `04-routing-engine.md` | Walk graph, transit graph, trip planning, arrive-by logic, re-planning, `TripTrace` |
| `05-arrival-prediction.md` | Bus arrival and ride-time prediction: baselines, ML model, evaluation, serving |
| `06-voice-agent.md` | Voice session design: constraint state, tools, events, spoken guidance |
| `07-grok-integration.md` | Every Grok touchpoint, tool contracts, prompts, verification, disruptions, Grok Bot, Cursor |
| `08-frontend-3d.md` | 3D renderer (Google Photorealistic 3D + sim world), live view, UI states, components |
| `09-api-spec.md` | REST and WebSocket endpoints with request/response shapes |
| `10-eval-explainability-demo.md` | Evaluation sets, metrics, explainability PDF outline, demo script |
| `11-build-plan.md` | Milestones and task checklist with acceptance criteria |

## One-paragraph summary

A user says "get me to Klaus by 8:30." The voice agent (Grok Voice Agent API) turns that into structured constraints and calls a **deterministic routing engine**. The engine uses our campus walk graph, the Stinger route graph, live bus positions, and a delay-prediction model. It returns the best plan: walk to a specific stop, catch a specific bus, ride, walk to the entrance. The plan has a "leave by" time and a probability of arriving on time. The 3D map flies into a live, step-by-step view. As the user adds requests ("avoid stairs," "make it 8:15") or the world changes (bus running late), the plan updates. Grok speaks only what changed, and every number it says is checked against the engine's output.

## Ground rules (read before writing any code)

1. **The router decides; Grok interprets and explains.** Grok never invents a time, distance, probability, stop, or route. Every such value comes from the routing engine's `TripTrace` and is verified before it is shown or spoken (`07-grok-integration.md` §6).
2. **Inventory before you build.** The first task is to inspect the data zip and write `DATA_INVENTORY.md` (`03-data-contracts.md` §1). Do not guess formats.
3. **Normalize once.** Raw data is converted by adapters into the normalized contracts in `03-data-contracts.md`. Everything downstream reads normalized data only.
4. **Replay is a first-class mode.** Every live feature must work against a recorded day so the demo never depends on buses running.
5. **Quantiles, not point estimates.** Predictions return distributions (p10/p50/p90 minimum). Plans carry probabilities.
6. **Ask, don't invent.** If a spec detail conflicts with the data or is ambiguous, stop and record the question in `OPEN_QUESTIONS.md` rather than inventing project facts.
7. **Units and time.** Meters, seconds, WGS84 lat/lng, timestamps in ISO 8601 with offset; local time zone `America/New_York`.
8. **Secrets stay server-side.** The xAI and Google Maps keys never ship in client bundles except a referrer-restricted Maps JS key.

## Glossary

| Term | Meaning |
|---|---|
| Stop | A Stinger bus stop (from the data zip) |
| Route | A Stinger route (ordered stop sequence + shape) |
| Walk graph | Pedestrian network: paths, crossings, stairs, ramps, building entrances, pass-throughs |
| Sim world | The project's existing 3D campus model / simulation environment (in the zip) |
| Plan | One candidate way to get from A to B (walk-only or walk + ride + walk) |
| `TripTrace` | The engine's full output for one planning request: chosen plan, alternatives, inputs, and why. The single source of truth |
| Constraints | The structured, accumulated user request (origin, destination, arrive-by, preferences) |
| `p_on_time` | Probability the plan arrives at or before `arrive_by` |
| `p_catch` | Probability the user reaches the boarding stop before the target bus departs |
| Session | One navigation interaction from first request to arrival |
| Replay | Feeding recorded bus positions through the live pipeline at 1x–20x speed |

## Rebuild order (high level)

1. Data inventory → normalization → georeferencing (03)
2. Walk graph + walk-only routing, rendered in 3D (04, 08)
3. Transit graph + bus routing with historical times (04)
4. Live/replay bus ingest + arrival predictor v1 (05)
5. Arrive-by planning + navigation session + re-planning (04, 09)
6. Text intent with Grok tools, then the voice session (06, 07)
7. Verification layer, disruption ingest, ops bots (07)
8. Evaluation, explainability PDF, demo (10)

Detailed tasks and acceptance criteria: `11-build-plan.md`.


---

# 01 — Product Spec

## 1. Problem

Getting around Georgia Tech on foot plus the Stinger is a multimodal decision that general-purpose maps handle poorly.

- **Campus geometry is irregular.** Elevated walkways, building pass-throughs with opening hours, stairs vs. ramps, construction closures, and covered routes all matter. A global map product does not curate these at campus resolution.
- **Bus timing is noisy.** Published headways hide variance from traffic, game days, class-change surges, and bus bunching.
- **The real decision is not "what's the route."** It is: should I wait for a bus or walk, which stop do I walk to, which bus do I take, and when do I need to leave to be on time?
- **Typing into a map while walking is bad UX.** People already know what they want ("Klaus by 8:30"). They should be able to say it.

## 2. Thesis

Inside a fixed, small, well-mapped boundary, a purpose-built system can beat a global map. It combines:

1. Our own campus walk graph and 3D sim world (hand-curated edge cases).
2. Live bus positions plus historical travel times and a delay model.
3. A voice/AI layer that understands requests and explains decisions, on top of a deterministic, auditable engine.

The bounded scope is the advantage: we can fix edge cases a global product can't afford to.

## 3. Users and needs

| User | Need | Feature that serves it |
|---|---|---|
| Student between classes | "Will I make it? Walk or bus?" | Arrive-by planning, `p_on_time`, leave-by time |
| New / international student, visitor | Doesn't know building nicknames or routes; may prefer another language | Alias resolution, multilingual voice, 3D landmarks |
| Mobility-impaired user (permanent or temporary) | Step-free, shorter, covered routes | Accessibility preferences, step-free walk graph |
| Low-vision user | Eyes-free guidance | Voice turn-by-turn |
| Night commuter | Safety | Night mode: lit paths, shorter exposed walks, night shuttle info |
| PTS / ops (stretch) | Where are delays happening | Delay analytics, drift reports |

## 4. Core user stories

1. **Voice trip:** As a user, I say "get me to the Klaus building," and the app finds the best walk + bus plan from where I am and starts a live 3D view.
2. **Deadline:** I say "I need to be there by 8:30," and the app tells me when to leave and how likely I am to make it.
3. **Stacking requests:** I add "avoid stairs" or "make it 8:15" mid-session, and the plan updates without starting over.
4. **Proactive updates:** If my bus is running late or leaves early, the app tells me unprompted and suggests the best fallback.
5. **Pick anywhere:** I can tap any point on the 3D map as start or end, not only named buildings.
6. **Why:** I can ask "why this bus?" and get a short, accurate explanation.
7. **Accessible:** I can say "I'm on crutches today," and the route avoids stairs and uses a slower walking speed.

## 5. Feature list and scope

### MVP (must ship)
- Start/end selection: current location, tap on 3D map, building search, or voice
- Walk-only and single-ride (walk → bus → walk) planning
- Arrive-by and depart-at planning with `p_on_time` and leave-by time
- Live or replayed bus positions on the map
- Step-by-step 3D live view: walk to stop, wait, ride, walk to entrance
- Voice session: request, stacked constraints, spoken guidance, proactive updates
- Grounded "why" explanation with verification
- Accessibility preferences: avoid stairs, walk speed, prefer covered

### Stretch
- Transfers between routes
- Disruption ingest from X and the web (`x_search` / `web_search`) with human approval
- "Where am I?" from a photo
- Night safety mode
- Waypoints ("grab coffee on the way")
- Grok Bot ops reports (data drift, model retraining)

### Out of scope
- Full indoor navigation (beyond whole-building pass-through edges)
- Accounts, saved places, push notifications
- Native mobile apps (responsive web only)
- Off-campus routing beyond the configured boundary

## 6. Success criteria

| Area | Metric | Target |
|---|---|---|
| Speed | Plan latency (request → `TripTrace`) | p95 < 1 s |
| Speed | Voice: end of user speech → first spoken word | p50 < 1.5 s |
| Accuracy | Wait-time MAE vs. schedule baseline | ≥ 30% better (adjust after first eval) |
| Accuracy | `p_on_time` calibration | Predicted 80–90% bucket actually on time 80–90% of the time on held-out data |
| Correctness | Plan choice vs. expert labels on 90 OD × time cases | ≥ 90% agreement |
| Grounding | Grok explanations passing number verification | ≥ 98%; failures fall back to templates 100% of the time |
| Intent | Voice/text request → correct structured constraints | ≥ 95% on the intent eval set |
| UX | First-time user: request → knows which stop to walk to | < 15 s |

## 7. Non-functional requirements

- Works on a recent phone browser (iOS Safari, Android Chrome) and desktop Chrome.
- Location data is used in-session only; not stored server-side beyond anonymized aggregate logs (configurable off).
- Graceful degradation: live feed down → schedule + history with a visible "estimated" badge; Grok down → deterministic templates and text UI; 3D slow → 2D fallback.
- All AI outputs are logged with their `trace_id` for audit.


---

# 02 — Architecture

## 1. Component diagram

```
┌──────────────────────────────── Web client (React + TS) ────────────────────────────────┐
│ 3D renderer (Google 3D / sim world) │ Live nav view │ Plan cards │ Why panel │ Mic/voice │
└───────┬───────────────────────────────────────┬────────────────────────────┬─────────────┘
        │ REST                                   │ WS /ws/session/{id}        │ WS /ws/voice/{id}
        │                                        │ (plan + nav events)        │ (audio relay)
┌───────▼────────────────────────────────────────▼────────────────────────────▼─────────────┐
│                                 API service (FastAPI, Python)                              │
│                                                                                            │
│  places/      routing/          prediction/       session/          grok/        verify/   │
│  - search     - walk graph      - wait model      - state machine   - text agent - number   │
│  - resolve    - transit graph   - ride model      - constraints     - voice relay  checker │
│               - planner         - quantiles       - replan triggers - disruptions          │
│               - TripTrace                         - event bus       - explainer            │
└───────┬───────────────────────┬─────────────────────────┬──────────────────────┬──────────┘
        │                       │                         │                      │
┌───────▼───────┐  ┌────────────▼──────────┐  ┌───────────▼──────────┐  ┌────────▼─────────┐
│ Bus ingest    │  │ Postgres + PostGIS    │  │ Redis                │  │ xAI API          │
│ live poller / │  │ normalized data,      │  │ live positions,      │  │ chat/responses,  │
│ replay player │  │ history, traces, logs │  │ session state, pubsub│  │ voice realtime,  │
└───────────────┘  └───────────────────────┘  └──────────────────────┘  │ collections      │
                                                                         └──────────────────┘
```

## 2. Request flows

### 2.1 Voice: "Get me to Klaus by 8:30"
1. Client opens `WS /ws/voice/{session_id}`; the server opens a Grok Voice Agent realtime connection (key stays server-side) and relays audio both ways.
2. Grok calls the tool `update_constraints({destination: "Klaus", arrive_by: "08:30"})`.
3. The server resolves "Klaus" → `building_id` + best entrance, merges into the session `Constraints`, calls `planner.plan(constraints, now)`.
4. Planner returns a `TripTrace`. The session pushes `plan_updated` on `/ws/session/{id}`; the client renders it in 3D.
5. The tool result returns a compact, voice-ready summary of the trace to Grok. Grok speaks it. The verifier checks the transcript against the trace (§07).
6. User says "start" → `start_navigation` → session enters `NAVIGATING`; client streams GPS on `/ws/session/{id}`.

### 2.2 Situation change
1. Ingest updates bus positions every 5–10 s → Redis pub/sub.
2. Session monitor re-evaluates the active plan (cheap path: recompute ETAs for the chosen bus only). If a trigger fires (`04-routing-engine.md` §8), it re-plans.
3. Server pushes `situation_changed` to the client and injects a context message into the voice session so Grok announces it.

### 2.3 Text / tap
Same planner. The text chat uses the same Grok tools through the Responses / Chat Completions API. Tap-to-pick skips Grok entirely.

## 3. Tech stack

| Layer | Choice | Notes |
|---|---|---|
| Frontend | React 18 + TypeScript + Vite | Zustand for state; Tailwind for styling |
| 3D | Google Maps JS Photorealistic 3D (`maps3d` library) **and** Three.js (or CesiumJS) for the sim world | Behind one `Renderer` interface (`08-frontend-3d.md`) |
| Backend | Python 3.12, FastAPI, Uvicorn | Async; Pydantic models shared via OpenAPI codegen to the client |
| Graph | networkx for build; precomputed matrices in numpy for speed | Upgrade to igraph if needed |
| ML | LightGBM (quantile objective), pandas/polars, scikit-learn | Reuse the existing bus-delay work where possible |
| DB | Postgres 16 + PostGIS | Normalized data, history, traces |
| Cache / pubsub | Redis | Live positions, session state |
| AI | xAI API: Grok 4.x text model, Grok Voice Agent (realtime), Collections | Model names via env vars |
| Infra | Docker Compose locally; web on Vercel, API on Fly.io/Render | Single region (us-east) |
| Tests | pytest, Vitest, Playwright | Golden-trace tests for the router |

## 4. Repo layout

```
buzz-route/
├── apps/
│   └── web/                     # React client
│       ├── src/renderer/        # Renderer interface + google3d/ + simworld/
│       ├── src/nav/             # live view, step list, session WS client
│       ├── src/voice/           # mic capture, audio playback, voice WS client
│       ├── src/api/             # generated API client
│       └── src/ui/              # cards, panels, search
├── services/
│   └── api/
│       ├── app/main.py
│       ├── app/places/
│       ├── app/routing/         # graph build, planner, trace
│       ├── app/prediction/      # wait/ride models, serving
│       ├── app/ingest/          # live poller, replay player
│       ├── app/session/         # state machine, constraints, triggers
│       ├── app/grok/            # text agent, voice relay, explainer, disruptions, prompts/
│       ├── app/verify/          # grounding checker
│       └── app/models.py        # Pydantic schemas (see 03 and 09)
├── data/
│   ├── raw/                     # extracted zip — read-only
│   ├── normalized/              # parquet/geojson outputs of adapters
│   ├── graphs/                  # built walk/transit graphs
│   ├── models/                  # trained predictor artifacts
│   └── replays/                 # recorded days
├── scripts/
│   ├── inventory.py             # writes DATA_INVENTORY.md
│   ├── normalize.py             # raw → normalized
│   ├── georef.py                # sim world ↔ WGS84 transform
│   ├── build_graphs.py
│   ├── train_predictor.py
│   ├── eval_*.py
│   └── record_replay.py
├── eval/                        # eval sets (JSON/CSV) and reports
├── docs/                        # this spec + DATA_INVENTORY.md + OPEN_QUESTIONS.md
├── docker-compose.yml
└── .env.example
```

## 5. Configuration (`.env.example`)

```bash
# Core
APP_ENV=dev
TZ=America/New_York
CAMPUS_BBOX=minLng,minLat,maxLng,maxLat   # set from data inventory
DATABASE_URL=postgresql://...
REDIS_URL=redis://localhost:6379

# Bus data
BUS_FEED_MODE=replay            # live | replay
BUS_FEED_URL=                   # confirm source (TransLoc feed behind bus.gatech.edu)
BUS_POLL_SECONDS=8
REPLAY_FILE=data/replays/weekday_sample.parquet
REPLAY_SPEED=1.0

# xAI
XAI_API_KEY=
XAI_BASE_URL=https://api.x.ai/v1
GROK_TEXT_MODEL=                # set to current Grok 4.x flagship from GET /v1/models
GROK_FAST_MODEL=                # cheaper/faster model for intent parsing if available
GROK_VOICE_MODEL=grok-voice-latest
GROK_VOICE_NAME=                # pick from available voices
XAI_COLLECTION_ID_CAMPUS=

# Google Maps
GOOGLE_MAPS_JS_KEY=             # referrer-restricted, client-side
RENDERER_DEFAULT=google3d       # google3d | simworld

# Planner defaults
WALK_SPEED_MPS=1.3
ACCESSIBLE_WALK_SPEED_MPS=0.8
MAX_ACCESS_WALK_M=700
ON_TIME_TARGET=0.9
MC_SAMPLES=300
```

## 6. Failure modes and degradation

| Failure | Detection | Behavior |
|---|---|---|
| Live bus feed down | No update > 60 s | Switch to schedule+history predictions; badge "estimated"; voice says it once |
| xAI text API error/timeout (> 4 s) | Exception / timeout | Template explanation; text UI still works |
| Voice connection drop | WS close | Auto-reconnect once; on failure show "voice unavailable," keep nav running |
| GPS poor (accuracy > 30 m) | Geolocation accuracy | Don't trigger off-route; show accuracy ring |
| Google 3D fails to load | Load error | Fall back to sim world or 2D |
| Verifier rejects Grok output | Mismatch | Use deterministic template; log for eval |


---

# 03 — Data Contracts

The project zip contains the bus data, the bus paths, and the sim world (3D campus). Exact formats are **not** assumed here. This document defines (1) how to inventory the zip, (2) the normalized schemas everything downstream depends on, and (3) how to align the sim world with real-world coordinates.

## 1. Step zero: inventory the zip

`scripts/inventory.py` must:

1. Extract the zip to `data/raw/` (read-only after extraction).
2. Walk every file and record: path, size, extension, detected type (CSV, JSON, GeoJSON, parquet, GTFS, glTF/GLB, OBJ, FBX, 3D Tiles `tileset.json`, Unity/Unreal scene, shapefile, SQLite, images, notebooks, code).
3. For tabular files: column names, dtypes, row count, 5 sample rows, min/max of any timestamp and lat/lng columns, null rates.
4. For geo files: CRS, bbox, geometry types, feature count.
5. For 3D assets: coordinate units, up-axis, bounding box, node/mesh names (often reveal building names), any embedded georeference.
6. For code/notebooks from the previous project: list what they compute (e.g., delay model features, training scripts).
7. Write `docs/DATA_INVENTORY.md` with a table per file and a **mapping proposal**: which raw file feeds which normalized table below, and which fields are missing.

Nothing else is built until a human reviews `DATA_INVENTORY.md`. Missing or ambiguous items go to `docs/OPEN_QUESTIONS.md`.

## 2. Normalized schemas

All outputs go to `data/normalized/` (parquet for tables, GeoJSON for geometry) and are loaded into Postgres. IDs are strings. Coordinates are WGS84. Times are ISO 8601 with offset or epoch ms (state which per column).

### 2.1 Transit

**`stops`**
| column | type | notes |
|---|---|---|
| stop_id | str | stable ID from source |
| name | str | |
| lat, lng | float | WGS84 |
| aliases | list[str] | nicknames, adjacent building names |
| accessible | bool? | curb/shelter info if known |
| sim_node_id | str? | matching object in the sim world |

**`routes`**
| column | type | notes |
|---|---|---|
| route_id | str | |
| name | str | |
| color | str | hex |
| is_loop | bool | most campus routes loop |
| active_days | str | e.g., `weekday`, `weekend`, `game_day` |

**`route_stops`** — ordered stop sequence
| route_id | seq | stop_id | dist_along_m |

**`route_shapes`** — GeoJSON LineString per route (and per direction if not a loop), with `dist_along_m` measurable along it.

**`service_spans`** — when a route runs
| route_id | day_type | start_local | end_local | headway_min | n_buses |

### 2.2 Bus history

**`vehicle_positions`** (raw-ish, normalized)
| ts | vehicle_id | route_id | lat | lng | heading_deg | speed_mps | source |

**`stop_events`** (derived by `normalize.py` from positions if not provided)
| vehicle_id | route_id | stop_id | seq | arrived_at | departed_at | dwell_s | trip_id |

Derivation: snap positions to the route shape; a stop event is the first point within 25 m of the stop (tunable) and the last before leaving it. Assign `trip_id` per loop lap.

**`segment_times`** (derived)
| route_id | from_stop_id | to_stop_id | depart_at | travel_s | hour | dow | day_type |

**`calendar`** — academic calendar and special days
| date | day_type | is_class_day | is_exam | is_game_day | is_holiday | notes |

If the zip has a previous delay dataset with extra features (weather, events), keep it and map it to the predictor's features in `05-arrival-prediction.md`.

### 2.3 Campus and walking

**`buildings`**
| building_id | name | aliases | footprint (Polygon) | centroid lat/lng | sim_object_id | hours (optional) |

**`entrances`**
| entrance_id | building_id | lat | lng | level | step_free | open_hours (optional) | walk_node_id |

**`walk_nodes`**
| node_id | lat | lng | level | kind (`intersection`/`entrance`/`stop`/`waypoint`) |

**`walk_edges`**
| edge_id | u | v | length_m | has_stairs | step_count | slope_pct | is_indoor | is_covered | lit_at_night | open_hours | surface | closed (bool) | source (`osm`/`simworld`/`manual`) |

Sources for the walk graph, in priority order:
1. Paths extracted from the sim world, if it has navigable paths or a navmesh.
2. OpenStreetMap footways for `CAMPUS_BBOX` (via osmnx `network_type="walk"`).
3. Manual edits in `data/normalized/walk_overrides.geojson` (add/close/annotate edges). Overrides always win.

Every stop and every entrance must connect to the walk graph (snap to the nearest edge, splitting it if needed). `build_graphs.py` fails if any stop/entrance is unreachable.

### 2.4 Sim world assets

**`world_manifest.json`**
```json
{
  "format": "glb | 3dtiles | other",
  "files": ["..."],
  "units": "meters",
  "up_axis": "Y",
  "local_origin": {"x": 0, "y": 0, "z": 0},
  "georef": { "method": "helmert2d", "params": {}, "rmse_m": 0.0 },
  "object_map": [{"sim_object_id": "...", "building_id": "..."}]
}
```

## 3. Georeferencing the sim world

The sim world probably uses local coordinates. To draw routes on it and on Google 3D at the same time, we need a transform.

1. Pick at least 6 control points visible in both the sim world and real coordinates (building corners, stop locations, intersections), spread across campus.
2. Fit a 2D similarity (Helmert: scale, rotation, translation) from sim (x, z) → local ENU meters around a campus origin, then ENU → WGS84. Height: constant offset or fit to known elevation.
3. Report RMSE. **Accept if RMSE ≤ 2 m**; otherwise add control points or fit an affine transform.
4. Store params in `world_manifest.json`. Expose `sim_to_wgs84()` and `wgs84_to_sim()` in both Python and TS (same params, unit-tested on the control points).

If the sim world already embeds a georeference (e.g., 3D Tiles with ECEF transform), validate it against the control points instead.

## 4. Data quality checks (`scripts/normalize.py --check`)

- Every `route_stops.stop_id` exists in `stops`.
- Route shape passes within 30 m of each of its stops.
- `segment_times.travel_s` within [5, 3600]; outliers flagged, not silently dropped.
- `stop_events` per trip are monotonic in time.
- Walk graph: one connected component containing all stops and entrances (or explicitly listed exceptions).
- Coverage report: history date range, days per day_type, buses per route per hour.

Output: `docs/DATA_QUALITY.md`.


---

# 04 — Routing Engine

Deterministic. Given constraints and a time, it returns a `TripTrace`. It is the **only** component that produces times, distances, and probabilities.

## 1. Inputs

```python
class Prefs(BaseModel):
    avoid_stairs: bool = False
    walk_speed_mps: float = 1.3          # accessible mode default 0.8
    prefer_covered: bool = False         # adds penalty to uncovered edges
    night_mode: bool = False             # penalty on unlit edges; caps exposed walking
    max_access_walk_m: int = 700         # max walk to/from a stop
    on_time_target: float = 0.9          # required p_on_time for arrive-by
    allow_transfers: bool = False        # stretch

class Constraints(BaseModel):
    origin: PlaceRef                     # {kind: "gps"|"building"|"entrance"|"stop"|"point", ...}
    destination: PlaceRef
    waypoints: list[PlaceRef] = []       # stretch
    arrive_by: datetime | None = None
    depart_at: datetime | None = None    # default: now
    prefs: Prefs = Prefs()
```

`PlaceRef` is resolved to a walk-graph node before planning: GPS/point → nearest walkable node (≤ 50 m, else error); building → best entrance (closest to the approach direction, step-free if `avoid_stairs`).

## 2. Graph build (`scripts/build_graphs.py`)

### 2.1 Walk graph
- Load `walk_nodes`, `walk_edges`, apply `walk_overrides`.
- Edge cost function, evaluated per request:
  ```
  t = length_m / walk_speed
  if has_stairs:   t += step_count * 0.6 s   (or ∞ if avoid_stairs)
  if slope_pct>5:  t *= 1 + (slope_pct-5)*0.05
  if prefer_covered and not is_covered: t *= 1.25
  if night_mode and not lit_at_night:   t *= 1.5
  if closed or outside open_hours:      t = ∞
  ```
- Precompute for default prefs: shortest walk time from every stop and every entrance to every other stop/entrance (matrix, ~hundreds × hundreds — small). Non-default prefs fall back to on-demand Dijkstra (still fast at campus scale).

### 2.2 Transit graph
- For each route: ordered stops, `dist_along_m`, shape.
- Ride time between any two stops on a route = sum of segment distributions (sampled, see §4), or a direct `(from, to)` distribution if history is dense enough.

## 3. Candidate generation

```
O = resolved origin node, D = resolved destination node, t0 = depart_at or now

candidates = [walk_only(O, D)]

board_stops  = stops with walk(O, s) ≤ max_access_walk_m
alight_stops = stops with walk(s, D) ≤ max_access_walk_m

for b in board_stops:
  for route r serving b:
    for a in alight_stops where a is downstream of b on r (loop-aware, ≤ 1 lap):
      candidates.append(ride_plan(O, b, r, a, D))

# Stretch: one transfer — for pairs of routes sharing a stop or stops within 150 m walk.
```

At campus scale this is tens to low hundreds of candidates; brute force is fine. Prune any candidate whose deterministic lower bound (walk + min ride, zero wait) is worse than walk-only by > 10 min.

## 4. Evaluating a ride candidate (Monte Carlo)

For each of `MC_SAMPLES` (default 300) samples:

1. `t_at_stop = t0 + walk(O, b)` (walk time multiplied by a small noise factor ~ N(1, 0.07)).
2. Sample the arrival times of the next K buses on route `r` at stop `b` from the predictor (`05`), conditioned on live positions. The user boards the first bus with `arrival ≥ t_at_stop + 15 s` buffer.
3. Sample ride time `b → a` on that bus (predictor).
4. `t_arrive = alight_time + walk(a, D)`.

From samples:
- `eta_p10, eta_p50, eta_p90`
- `p_catch` = share of samples boarding the *target* bus (the earliest bus the plan names)
- `p_on_time` = share with `t_arrive ≤ arrive_by` (if set)
- `wait_p50`, `ride_p50`, `walk_total_s`

Walk-only is deterministic (plus the same walk noise).

Use a fixed RNG seed per `(trace inputs hash)` so identical requests return identical traces (needed for verification and tests).

## 5. Ranking

**Depart-now mode (no deadline):** minimize `eta_p50`. Tiebreak (within 60 s): higher `p_catch`, then less walking, then fewer stairs. Show walk-only as an alternative whenever it's within 3 min.

**Arrive-by mode:** see §6.

## 6. Arrive-by planning

Goal: the latest **leave-by** time that still meets `p_on_time ≥ on_time_target`, and the best plan for that.

```
for each candidate c:
  binary search departure time t in [now, arrive_by]:
    p(t) = p_on_time(c, depart_at=t)        # MC as in §4
    find latest t* with p(t*) ≥ target
  c.leave_by = t*  (or None if even t=now fails)

feasible = [c for c in candidates if c.leave_by is not None]
if feasible:
  choose c maximizing leave_by (more slack is better); tiebreak: higher p_on_time at now, less walking
else:
  choose c maximizing p_on_time at t=now; mark trace.status = "at_risk"
```

Notes:
- Departure-time search granularity: 30 s; cap at 20 iterations per candidate.
- If the user is already late under every plan, say so and give the fastest plan with its `eta_p50`.
- Report both "leave by" and "if you leave now you'll arrive ~X, Y% on time."

## 7. `TripTrace` (output contract)

```jsonc
{
  "trace_id": "tr_01H...",
  "created_at": "2026-11-03T08:05:12-05:00",
  "status": "ok | at_risk | infeasible | degraded",
  "constraints": { /* resolved Constraints, incl. node ids */ },
  "inputs": {
    "bus_positions_at": "2026-11-03T08:05:05-05:00",
    "feed_mode": "live | replay | schedule_only",
    "predictor_version": "wait-v2.1",
    "graph_version": "walk-2026-11-01",
    "disruptions_applied": ["dz_123"],
    "mc_samples": 300,
    "seed": 18237
  },
  "chosen": {
    "plan_id": "p1",
    "mode": "walk_ride_walk",
    "leave_by": "2026-11-03T08:09:30-05:00",
    "eta": {"p10": "08:20", "p50": "08:23", "p90": "08:27"},
    "p_on_time": 0.93,
    "p_catch": 0.84,
    "legs": [
      {"type": "walk", "from": "gps", "to": "stop:ferst_atlantic", "distance_m": 310, "duration_s": 240,
       "has_stairs": false, "geometry": "<encoded polyline>", "steps": [ /* §9 */ ]},
      {"type": "wait", "stop_id": "ferst_atlantic", "target_vehicle_id": "bus_14",
       "route_id": "route_x", "arrival": {"p10": "08:13", "p50": "08:14", "p90": "08:16"}},
      {"type": "ride", "route_id": "route_x", "from_stop": "ferst_atlantic", "to_stop": "klaus_stop",
       "n_stops": 3, "duration_s": {"p50": 290, "p90": 380}, "geometry": "<encoded polyline>"},
      {"type": "walk", "from": "stop:klaus_stop", "to": "entrance:klaus_main", "distance_m": 120, "duration_s": 95}
    ]
  },
  "alternatives": [
    {"plan_id": "p0", "mode": "walk_only", "leave_by": "08:06:00", "eta": {"p50": "08:26"},
     "p_on_time": 0.99, "rejected_because": "leaves 3.5 min earlier than p1"}
  ],
  "fallback_if_missed": {"next_vehicle_id": "bus_9", "arrival_p50": "08:24",
                         "eta_p50": "08:33", "walk_only_eta_p50": "08:29", "recommend": "walk"},
  "explanation_facts": [
    "bus_14 is 2 stops upstream",
    "segment ferst_atlantic→klaus_stop p50 290 s at 08:00 on weekdays"
  ]
}
```

`explanation_facts` are short, machine-generated facts the explainer may use. They are the only "reasons" Grok is allowed to cite.

## 8. Re-planning triggers (during a session)

The session monitor re-evaluates on every bus update and every GPS update:

| Trigger | Condition | Action |
|---|---|---|
| Constraint change | User adds/changes a constraint | Full re-plan; event `plan_updated` |
| Target bus slip | Target bus `arrival_p50` moves > 90 s | Re-evaluate chosen plan; if another plan now wins by > 60 s or `p_catch` < 0.5, re-plan; event `situation_changed` |
| Missed bus | Target bus departs stop and user not within 20 m | Switch to `fallback_if_missed` re-plan |
| Off-route | GPS > 25 m from current leg geometry for > 10 s (accuracy ≤ 20 m) | Re-plan from current position |
| Deadline risk | `p_on_time` drops below target | Re-plan; announce risk |
| Disruption | New approved disruption affects the plan | Re-plan |

Debounce: at most one re-plan announcement per 30 s unless the plan's mode or bus changes.

## 9. Step generation (turn-by-turn)

For walk legs, produce steps from the polyline:
- Merge consecutive edges with heading change < 30°.
- Each step: `instruction`, `distance_m`, `heading_change` (`left`/`right`/`slight_left`/…), `landmark` (nearest building or stop within 40 m, from `buildings`), `maneuver_point` lat/lng.
- Instruction templates are deterministic, e.g., "Turn left toward the Clough Commons, 80 meters." Grok may rephrase in voice, but distances come from these fields.

Ride legs: "Board route X toward <next major stop>. Ride 3 stops. Get off at <stop>." The next-stop announcement triggers when the bus position passes the previous stop.

## 10. Tests

- **Golden traces:** 30 fixed OD × time cases on a fixed replay snapshot → snapshot-tested `TripTrace` (with seed).
- **Property tests:** walk-only always present; `eta_p10 ≤ p50 ≤ p90`; `p_on_time` monotonically non-increasing in departure time; avoid-stairs plans contain no stair edges.
- **Performance:** 100 random requests, p95 < 1 s on a laptop.


---

# 05 — Arrival and Ride-Time Prediction

Purpose: give the planner **distributions** for (a) when the next K buses of a route will arrive at a stop and (b) how long a ride between two stops takes. Reuse the existing bus-delay ML work from the zip where possible; the inventory step should list its features and code.

## 1. Interface

```python
class Predictor(Protocol):
    def next_arrivals(self, route_id: str, stop_id: str, after: datetime, k: int,
                      live: LiveSnapshot | None, n_samples: int, rng) -> np.ndarray:
        """shape (n_samples, k): arrival times (epoch s) of the next k buses at stop."""

    def ride_time(self, route_id: str, from_stop: str, to_stop: str, depart: datetime,
                  n_samples: int, rng) -> np.ndarray:
        """shape (n_samples,): seconds."""

    def quantiles(...) -> dict  # p10/p50/p90 convenience for UI and traces
    version: str
```

## 2. Model ladder (build in order; each must beat the previous on eval)

### L0 — Schedule baseline
- Wait ~ Uniform(0, headway) from `service_spans`; ride = historical median.
- Exists so every later model has a baseline to beat and so the system works with no live data.

### L1 — Empirical history
- Ride: empirical distribution of `segment_times` for `(route, segment, hour, day_type)`; sum segments by sampling (bootstrap), with fallback to coarser buckets when fewer than 30 observations.
- Wait without live data: empirical headway distribution at that stop/hour.

### L2 — Live-conditioned
- For each active bus on the route, compute progress along the route (snap to shape → `dist_along_m` → previous stop + fraction).
- Time-to-stop = remaining fraction of current segment (scaled) + sampled downstream segment times + sampled dwell at intermediate stops.
- Upcoming buses not yet in service: from `service_spans` + history.
- Handle loops: a bus just past the stop arrives next lap.

### L3 — ML residual model (the existing delay work)
- Target: residual between actual and L2 median predicted time-to-stop (or actual segment time vs. L1 median).
- Model: LightGBM with quantile objective, three models for α = 0.1, 0.5, 0.9 (or one model + conformal intervals).
- Features (use what the data supports):
  - route_id, from/to stop, segment index, distance remaining
  - hour, minute-of-day (cyclical), day-of-week, day_type, is_class_change_window (±10 min of common class start/end times), is_exam, is_game_day, is_holiday
  - upstream delay of this bus (actual vs. L1 at last 1–3 stops)
  - headway to the bus ahead/behind (bunching)
  - number of active buses on the route
  - weather (precip, temp) if available in the zip
- Samples: draw from a distribution fitted to the predicted quantiles (e.g., piecewise-linear inverse CDF through p10/p50/p90, clipped ≥ 0).

## 3. Training and evaluation

- Split by **time**: train on older weeks, validate on next, test on the most recent N weeks (no shuffling).
- Metrics, reported per route and per hour bucket (not just overall):
  - MAE and median absolute error of p50
  - Interval coverage: share of actuals inside [p10, p90] (target ≈ 80%)
  - Pinball loss for each quantile
  - Calibration of `p_catch` / `p_on_time`: reliability diagram on simulated user trips
- Explainability outputs: SHAP summary for L3; per-prediction top-3 contributors available for the "why" panel (e.g., "running 2 min behind at the last stop").
- Artifacts: `data/models/<version>/` with model files, feature list, metrics JSON, training data hash.

## 4. Serving

- Load models at API start. Live snapshot cached in Redis, refreshed by ingest.
- Target latency: `next_arrivals` with 300 samples for one route/stop < 20 ms.
- Cache predictions per `(route, stop, snapshot_ts)` for 5 s.
- If live data is stale (> 60 s), drop to L1 and set `trace.status = "degraded"`.

## 5. Replay

`scripts/record_replay.py` stores a day's `vehicle_positions` as parquet. The replay player publishes them to Redis at `REPLAY_SPEED` with timestamps shifted to "now," so the whole stack (predictor, sessions, voice announcements) runs exactly as live. Keep at least: one normal weekday, one rainy day (if available), and one game day (if available).


---

# 06 — Voice Agent

The headline interaction: say where you want to go (and by when), get the best walk + bus plan, and follow a live 3D view with spoken guidance. Keep stacking requests; the plan updates.

## 1. Platform

- **Grok Voice Agent API**: realtime speech-to-speech over WebSocket (`wss://api.x.ai/v1/realtime`). Its event protocol is compatible with the OpenAI Realtime API (`session.created`, `session.update`, `conversation.item.create`, `response.create`, function-call events, `response.done`, audio deltas). It supports tool/function calling and multiple languages.
- Model: `GROK_VOICE_MODEL` (alias `grok-voice-latest` → currently `grok-voice-think-fast-1.0`). Confirm current names and voices in docs.x.ai before building.
- Verify exact event names and payloads against the current xAI docs; this spec uses the OpenAI-Realtime-compatible names.

### Transport choice
| Option | How | Pros | Cons |
|---|---|---|---|
| **A. Server relay (MVP)** | Browser ↔ our `WS /ws/voice/{session}` ↔ xAI realtime | Key never leaves server; we see every tool call and transcript (needed for verification) | We handle audio framing; extra hop |
| B. LiveKit + xAI plugin | Browser ↔ LiveKit room ↔ agent worker | Robust WebRTC, echo cancellation, turn detection | More infra |

Start with A. Move to B if audio quality or latency on mobile networks is a problem.

## 2. Session model

One **navigation session** per user interaction, holding:

```python
class SessionState(BaseModel):
    session_id: str
    phase: Literal["IDLE","PLANNING","PREVIEW","NAVIGATING","REPLANNING","ARRIVED","ENDED"]
    nav_step: Literal["WALK_TO_STOP","AT_STOP","ON_BUS","WALK_TO_DEST"] | None
    constraints: Constraints          # accumulated across utterances
    constraint_history: list[ConstraintPatch]
    current_trace_id: str | None
    last_gps: GpsFix | None
    language: str = "en"
    announced: dict                   # what we've already told the user, for dedup
```

### State machine
```
IDLE ──request──▶ PLANNING ──trace──▶ PREVIEW ──"start"/auto──▶ NAVIGATING ──arrive──▶ ARRIVED
                     ▲                   │                         │
                     └──constraint patch─┴─────────────────────────┘ (REPLANNING then back)
```
Auto-start: if the user said "take me…" / "navigate…", go straight from PREVIEW to NAVIGATING after speaking the summary. If they asked a question ("how do I get…"), stay in PREVIEW.

## 3. Constraint stacking

Every utterance that changes the trip becomes a **patch**, not a new request:

```jsonc
// "I want to get to Klaus"
{"op": "set", "destination": {"query": "Klaus"}}
// "by 8:30"
{"op": "set", "arrive_by": "08:30"}
// "actually avoid stairs, I'm on crutches"
{"op": "set", "prefs": {"avoid_stairs": true, "walk_speed_mps": 0.8}}
// "make it 8:15"
{"op": "set", "arrive_by": "08:15"}
// "stop by the coffee place on the way"   (stretch)
{"op": "add_waypoint", "waypoint": {"query": "coffee"}}
// "never mind the coffee"
{"op": "remove_waypoint", "index": 0}
// "start over"
{"op": "reset"}
```

Rules:
- Times are interpreted in local time; "8:30" means the next occurrence of 08:30 today, or tomorrow if past (confirm verbally if tomorrow).
- Relative times ("in 20 minutes") are converted server-side, not by the model.
- Origin defaults to live GPS unless the user names one ("from the CRC").
- Ambiguous places: `resolve_place` returns candidates; if top confidence < 0.75 or two candidates within 0.1, Grok asks a short clarifying question listing at most 2 options.
- Each applied patch triggers a full re-plan; the reply confirms **only what changed** ("Got it, avoiding stairs. Still the 8:14 bus, now leave by 8:07.").

## 4. Tools exposed to the voice model

All tools are executed by our server. Results are compact JSON designed to be spoken from.

```jsonc
update_constraints(patch: ConstraintPatch)
  -> { status, applied: {...}, clarification?: {question, options[]},
       plan_summary?: VoiceSummary }

get_plan() -> VoiceSummary                 // current plan, for "what's the plan again?"
get_bus_status(route_id?, stop_id?) -> {buses: [{route, minutes_away_p50, stops_away}]}
start_navigation() -> {status, first_instruction}
next_instruction() -> {instruction, distance_m}
explain_plan(question?) -> {facts: [...]}  // from TripTrace.explanation_facts
end_session() -> {status}
```

`VoiceSummary` (derived deterministically from `TripTrace`):
```jsonc
{
  "trace_id": "tr_...",
  "mode": "walk_ride_walk",
  "leave_by_local": "8:07",
  "arrive_p50_local": "8:23",
  "p_on_time_pct": 93,
  "board_stop_name": "Ferst Dr at Atlantic",
  "walk_to_stop_min": 4,
  "route_name": "Route X",
  "bus_minutes_away": 3,
  "ride_stops": 3,
  "alight_stop_name": "Klaus",
  "fallback": "If you miss it, walking gets you there by 8:29.",
  "status": "ok"
}
```

## 5. Proactive announcements (server → voice)

When the session monitor emits an event, the server injects a context item into the voice session and requests a response:

```jsonc
// conversation.item.create
{"type":"message","role":"system","content":[{"type":"input_text","text":
 "EVENT situation_changed: target bus now 5 min away (was 3). Plan unchanged. leave_by 8:07 → 8:09. p_on_time 93% → 91%. Announce briefly."}]}
// then response.create
```

Announcement policy (prevents chattiness):
| Event | Announce? |
|---|---|
| Plan mode or bus changes | Always |
| `leave_by` or ETA shifts ≥ 2 min | Yes |
| `p_on_time` crosses below target | Yes, with the best alternative |
| Shift < 2 min, same plan | No (UI updates silently) |
| Turn instruction | 30–40 m before the maneuver point, and at it |
| Bus approaching | At 2 min and 30 s out while user is at the stop |
| Next stop is yours | When the bus departs the previous stop |

Never interrupt the user mid-utterance; queue and play after their turn ends. While the user is speaking, the server holds proactive events.

## 6. System instructions for the voice model (draft)

```
You are a campus navigation voice guide for Georgia Tech.
- Use tools for anything about places, buses, times, or routes. Never estimate them yourself.
- Speak only numbers that appear in the latest tool result. Round to whole minutes.
- Keep turns short: one or two sentences. Lead with the action ("Leave by 8:07 and walk to Ferst at Atlantic").
- When the user adds a request, confirm only what changed.
- If a place is ambiguous, ask one short question with at most two options.
- Mention the fallback when on-time chance is below 90%.
- Never tell the user to run, cross against signals, or take unsafe shortcuts.
- Respond in the user's language.
```

## 7. Client audio

- Mic capture with `getUserMedia`, echo cancellation and noise suppression on; resample to the format the realtime API expects (confirm sample rate/encoding in docs; commonly 16-bit PCM).
- Push-to-talk button as default on mobile (more reliable in noisy outdoor settings); hands-free mode with server VAD as a toggle.
- Show a live transcript (user and assistant) under the map, for accessibility and for demo clarity.
- Haptic tick on turn instructions (if supported).

## 8. Latency budget (target p50)

| Stage | Budget |
|---|---|
| End of speech detection | 300 ms |
| Model to tool call | 400 ms |
| Tool execution (resolve + plan) | 300 ms |
| Model to first audio | 400 ms |
| **Total to first spoken word** | **~1.4 s** |

Speed tricks: precomputed walk matrices; cache `resolve_place`; return `VoiceSummary` (small) not the full trace; render the map on `plan_updated` before speech finishes.

## 9. Failure handling

| Case | Behavior |
|---|---|
| Tool error | Grok says "I couldn't get that plan, try again" and the UI shows the error |
| Infeasible deadline | "You can't make 8:15 by bus or on foot; the fastest gets you there at 8:21. Want that?" |
| GPS unavailable | Ask "Where are you starting from?" |
| Voice drop mid-navigation | Navigation continues; UI instructions remain; reconnect resumes with `get_plan` |
| Verifier mismatch on spoken text | Log; the next turn re-reads the correct plan ("Correction: leave by 8:09") |

## 10. Example session

```
User:  Get me to Klaus.
Grok:  [update_constraints {destination: Klaus}] Walk 4 minutes to Ferst at Atlantic; Route X is 3 minutes out.
       You'll be at Klaus around 8:12. Starting now.
User:  I need to be there by 8:30 actually, and I want to grab coffee.
Grok:  [update_constraints {arrive_by: 8:30}] [update_constraints {add_waypoint: coffee}]
       Which coffee: the one in the library or in Clough?
User:  Clough.
Grok:  Got it. Walk to Clough first, then catch Route X at 8:19. You'll arrive about 8:26, 91% on time.
...
Grok:  Heads up: your bus is running 4 minutes late. Walking from Clough now still gets you there by 8:28.
```


---

# 07 — Grok Integration

> Researched 2026-11-02. xAI changes models and features quickly; confirm against docs.x.ai and `GET /v1/models` before implementing.

## 1. Principle

Grok handles what is genuinely fuzzy: understanding people, explaining decisions, and reading unstructured real-world signals. The routing engine handles everything numeric. Grok reaches the engine only through typed tools, and its outputs are verified.

## 2. xAI platform capabilities used

| Capability | Use in this project |
|---|---|
| Grok 4.x text models (function calling, structured outputs, image input, long context) | Text chat agent, intent parsing, explanation, disruption extraction, photo localization |
| OpenAI-compatible API: `/v1/chat/completions` and `/v1/responses` | Use the OpenAI SDK or `xai-sdk` with `base_url=https://api.x.ai/v1` |
| Server-side tools on the Responses API: `web_search`, `x_search`, code execution, remote MCP | Disruption ingest; analyst mode |
| ⚠️ Legacy `search_parameters` live-search field | **Removed** (returns 410). Use Responses API tools |
| Collections API (hosted RAG; semantic/keyword/hybrid search; metadata) via `collections_search` / `file_search` | Campus knowledge base: building aliases, entrances, accessibility notes, PTS policies |
| Voice Agent API (realtime) | `06-voice-agent.md` |
| Grok Bot (beta; always-on agents on their own cloud computers; access via SuperGrok Heavy, Cursor Ultra, Cursor Teams Premium; enterprise waitlist) | Ops teammate (§8) — confirm access |
| Cursor (with Grok models) | Build environment + integration log (§9) |

The xAI console requires prepaid credits before API calls work. Budget voice minutes for rehearsal.

## 3. Touchpoints (priority order)

| # | Touchpoint | Grok feature | Phase |
|---|---|---|---|
| T1 | Voice navigation session | Voice Agent API + tools | MVP |
| T2 | Text chat / search bar intent | Text model + function calling + structured outputs | MVP |
| T3 | Place resolution with campus nicknames | Collections search | MVP |
| T4 | Grounded "why this route" explanation | Text model over `TripTrace.explanation_facts` | MVP |
| T5 | Verification of every Grok number | Our code (§6) | MVP |
| T6 | Accessibility preference inference ("I'm on crutches") | Function calling → `Prefs` | MVP |
| T7 | Disruption ingest | `x_search` + `web_search` + structured output | Stretch |
| T8 | "Where am I?" from a photo | Image input + Collections | Stretch |
| T9 | Night safety mode guidance | Collections (policy docs) | Stretch |
| T10 | Grok Bot ops reports | Grok Bot | Stretch |
| T11 | Analyst mode ("why is this route late at noon?") | Code execution tool over history extracts | Stretch |

Explicitly **not** done: Grok generating routes or times; Grok predicting delays (the ML model does that, measurably).

## 4. Campus knowledge base (Collections)

Build `scripts/build_collection.py` to upload one document per building and per stop, plus policy docs:

```markdown
# Building: Klaus Advanced Computing Building
building_id: klaus
aliases: Klaus, KACB, the Klaus building
entrances: klaus_main (step-free), klaus_ferst (stairs)
nearby_stops: klaus_stop, ferst_atlantic
notes: <curated campus notes; e.g., covered walkway connections>
```

Metadata fields: `kind` (`building`/`stop`/`policy`), `building_id`, `stop_id`.

`resolve_place(query)` flow:
1. Exact/fuzzy match on names and aliases locally (fast path, no API call).
2. If no confident match: Collections hybrid search → top 5 → return candidates with scores.
3. Return `{candidates: [{kind, id, name, lat, lng, confidence}], needs_clarification}`.

## 5. Text agent (T2, T4, T6)

### Tools (shared with voice where possible)
```jsonc
resolve_place(query: string) -> ResolveResult
update_constraints(patch: ConstraintPatch) -> {status, applied, clarification?, plan_summary?}
plan_trip(constraints: Constraints) -> {trace_id, summary: VoiceSummary}
get_bus_status(route_id?: string, stop_id?: string) -> BusStatus
explain_plan(trace_id: string, question?: string) -> {facts: string[], summary: VoiceSummary}
get_disruptions(active_only: boolean) -> Disruption[]
```

### Intent parsing with structured outputs
For the search bar ("klaus by 830 no stairs"), call the fast model with a JSON schema for `ConstraintPatch[]`. Deterministic post-processing converts times and resolves places. Fall back to a simple regex parser if the API fails.

### Explainer prompt (T4)
```
You explain a campus trip plan in 2-3 short sentences for a student.
Use ONLY facts and numbers from the provided JSON (summary + facts). Round times to the minute.
Structure: what to do → why this beats the alternative → what happens if the bus is missed.
If on-time probability < 90%, say so plainly. No exclamation marks. No advice to run.
```
Input: `VoiceSummary` + `explanation_facts` + top alternative. Output must pass §6.

## 6. Verification layer (grounding check)

Applies to every Grok text and voice transcript that the user sees or hears.

1. **Extract claims:** times (`8:07`, `8:07 AM`, `in 4 minutes`), durations, distances, percentages, stop/route/building names. Use regex plus a name gazetteer from normalized data.
2. **Build the allowed set** from the trace: all times in `VoiceSummary`, legs, alternatives, fallback (formatted variants and ±1 min rounding), percentages ±1, distances within 10%, durations within ±1 min, names from the trace.
3. **Check:** every extracted claim must be in the allowed set.
4. **On failure:**
   - Text: replace with the deterministic template explanation; log `verify_fail` with diff.
   - Voice: already spoken, so the next turn speaks a correction from the template; log it.
5. **Report:** pass rate on eval sets goes into the explainability PDF.

Optionally run the voice model with tool-result-only phrasing pressure (system prompt + short `VoiceSummary`) to keep the failure rate near zero. This layer is conceptually an agent-verification layer; if the team has an existing verifier (e.g., Tycho), it can slot in here.

## 7. Disruption ingest (T7)

Scheduled every 10 minutes (and on demand):

```python
resp = client.responses.create(
    model=GROK_TEXT_MODEL,
    tools=[{"type": "x_search"}, {"type": "web_search"}],
    input=DISRUPTION_PROMPT,     # look for Georgia Tech Stinger detours, closures, campus events, weather today
    text={"format": {"type": "json_schema", "schema": DISRUPTION_SCHEMA}}
)
```

```jsonc
// Disruption
{
  "disruption_id": "dz_123",
  "type": "detour | stop_closed | road_closed | path_closed | service_suspended | event_crowding | weather",
  "routes": ["route_x"], "stops": ["ferst_atlantic"], "edges": [],
  "valid_from": "...", "valid_until": "...",
  "summary": "one sentence",
  "source_urls": ["..."],
  "confidence": 0.0-1.0,
  "status": "proposed | approved | rejected | expired"
}
```

- Map named places to IDs with `resolve_place`; unmappable → keep as banner-only.
- **Human approval required** before a disruption changes routing (admin page or Grok Bot chat approval). Demo mode: one-click approve.
- Approved disruptions apply penalties: closed stop → removed for boarding/alighting; detour → ride-time inflation; path closed → edge `closed=true`.
- Every plan lists `disruptions_applied`; the UI shows a banner with the source link.

## 8. Grok Bot as ops teammate (T10)

Grok Bot is a beta product of persistent agents running on their own cloud computers, able to use tools and complete multi-step tasks. Proposed bots:

| Bot | Job | Output |
|---|---|---|
| Data-ops bot | Nightly: export the day's bus logs, run `eval_predictor.py`, compare with last week, flag drifted routes/hours | Message in team chat + issue with metrics table |
| Disruption triage bot | Review proposed disruptions, check sources, recommend approve/reject | Approval requests in team chat |
| Release bot (optional) | Retrain predictor when drift > threshold, open a PR with new metrics | PR |

**Prerequisite:** someone on the team has Grok Bot access. If not, implement the same jobs as scheduled scripts that call the Grok API, and describe Grok Bot as the deployment target.

## 9. Cursor + Grok development log

- Build the project in Cursor with a Grok model as the coding model where practical.
- Keep `docs/AI_DEV_LOG.md`: date, task, prompt summary, what the model produced, what was wrong, what was kept. Ten good entries are better than fifty vague ones.
- This log is the evidence for "real integration" in judging, and it doubles as material for the explainability PDF.

## 10. Photo localization (T8, stretch)

1. User taps camera, takes a photo.
2. Send the image + list of buildings near the GPS fix (if any) to the text model: "Which of these buildings is shown? Return building_id and confidence."
3. Confidence ≥ 0.8 → set origin to that building's nearest entrance; else ask the user to pick from the top 2.

## 11. Cost and rate control

- Cache `resolve_place` and explanation results by `(trace inputs hash)`.
- Fast/cheap model for intent parsing; flagship only for explanations and disruption extraction.
- Disruption ingest at most every 10 minutes.
- Log tokens and voice minutes per session; show a running total on the admin page.


---

# 08 — Frontend and 3D Live View

## 1. Renderer abstraction

Two renderers behind one interface, so the app works on Google's photorealistic 3D or on our sim world.

```ts
interface Renderer {
  mount(el: HTMLElement): Promise<void>;
  setCamera(c: {lat: number; lng: number; alt: number; heading: number; tilt: number; range: number}): void;
  flyTo(c: CameraTarget, durationMs: number): Promise<void>;
  followPath(path: LatLngAlt[], opts: {speedMps: number; heading: "path" | number}): Controller;
  drawRoute(id: string, path: LatLngAlt[], style: RouteStyle): void;   // walk vs. bus styles
  removeRoute(id: string): void;
  upsertMarker(id: string, m: MarkerSpec): void;                       // stops, buses, user, entrances
  removeMarker(id: string): void;
  highlightBuilding(buildingId: string | null): void;
  onPick(cb: (p: {lat: number; lng: number; buildingId?: string}) => void): void;
}
```

### 1.1 Google Photorealistic 3D (`google3d`)
- Maps JavaScript API, `maps3d` library: `<gmp-map-3d>` (`Map3DElement`), `Polyline3DElement` for routes, `Marker3DElement` / interactive markers for stops, buses, user; camera animation (`flyCameraTo`, `flyCameraAround`).
- Polylines: `altitudeMode: "relative-to-ground"` (or clamp-to-ground), walk legs dashed/lighter, ride legs in route color, wider.
- Markers can be hidden behind buildings; set `drawsWhenOccluded` for the user marker and active stop.
- Building highlight: `Polygon3DElement` extruded from the `buildings.footprint`.
- Check current 3D Maps JS API version and availability in the Maps docs; it has been evolving (alpha/beta channels).

### 1.2 Sim world (`simworld`)
- Three.js (GLB/glTF) or CesiumJS (if the sim world is 3D Tiles).
- Use the georeference from `world_manifest.json` (`03` §3) to convert lat/lng ↔ scene coords; same `Renderer` API.
- Picking: raycast against building meshes → `sim_object_id` → `building_id`.
- Performance: Draco/meshopt compression, LOD, frustum culling; target 30+ fps on a mid-range phone.

Default renderer: `RENDERER_DEFAULT` env; a toggle in settings. The sim world is the differentiator (shows our curated paths and pass-throughs); Google 3D is the polished real-world look.

## 2. Screens and states

```
┌───────────────────────────────────────────┐
│  [From: My location ▾]  [To: ______ 🎤]   │  ← search bar + mic
│                                           │
│               3D MAP                      │
│                                           │
│  ┌─────────────────────────────────────┐  │
│  │ Leave by 8:07 · Arrive ~8:23 · 93%  │  │  ← plan card (bottom sheet)
│  │ 🚶 4 min → 🚌 Route X (3 min away)  │  │
│  │ → 3 stops → 🚶 2 min                │  │
│  │ [Start]   [Why?]   [Walk instead]   │  │
│  └─────────────────────────────────────┘  │
└───────────────────────────────────────────┘
```

| Phase | Map | Bottom sheet | Voice |
|---|---|---|---|
| IDLE | Overview, tilted campus | Search + recent | Mic idle |
| PLANNING | Pins at origin/dest | Spinner (< 1 s) | "Finding the best way…" only if > 1 s |
| PREVIEW | Full route drawn; camera frames whole trip; live buses on route | Plan card + alternatives | Summary spoken |
| NAVIGATING / WALK_TO_STOP | Camera follows user, 45° tilt, heading-up; next maneuver arrow | Current instruction, distance, bus countdown | Turn prompts |
| NAVIGATING / AT_STOP | Camera frames stop + approaching bus | Big countdown: "Route X · 2 min" | Bus approach alerts |
| NAVIGATING / ON_BUS | Camera follows bus marker along route | "3 stops · get off at Klaus" | Next-stop alert |
| NAVIGATING / WALK_TO_DEST | Follow user to entrance; entrance highlighted | Final instruction | "Entrance on your left" |
| REPLANNING | Old route fades, new route draws | Change banner: "Bus late — walking now" | Change announced |
| ARRIVED | Building highlighted | "Arrived 8:22 · on time" | "You're here." |

## 3. Live view mechanics

- GPS: `navigator.geolocation.watchPosition` with high accuracy; send fixes on `/ws/session/{id}` at ≤ 1 Hz.
- Snap the user marker to the current leg if within accuracy radius; otherwise show the raw fix.
- Camera follow: smooth with a critically damped spring on position and heading; never update the camera faster than 10 Hz.
- **Demo mode:** "simulate walk" moves the user along the leg geometry at walking speed, so the live view works indoors and on stage. Combine with replay for buses.
- Bus markers: interpolate between position updates along the route shape (not straight lines) so buses glide.

## 4. "Why?" panel

- Shows the Grok explanation (verified badge ✓ or "template" label when the fallback was used).
- Expandable "numbers" section rendering the `TripTrace`: legs, quantiles, `p_on_time`, alternatives with `rejected_because`, inputs (feed mode, predictor version, disruptions).
- Small chart: ETA distribution histogram for chosen vs. top alternative, with the deadline line.

## 5. Accessibility

- Every map state also expressed as text in the bottom sheet (screen-reader friendly, ARIA live region for instruction changes).
- High-contrast route colors; don't rely on color alone (walk = dashed, bus = solid).
- Text size follows system settings; minimum tap target 44 px.
- Voice transcript visible.

## 6. Visual style

- Clean, flat, high contrast. Small corner radii (4–6 px). No purple gradients.
- Route colors from `routes.color`; walking in neutral dark gray / white depending on basemap.
- Motion: camera transitions 800–1500 ms; respect `prefers-reduced-motion` (cut instead of fly).

## 7. Client state (Zustand)

```ts
type AppState = {
  session: {id: string; phase: Phase; navStep?: NavStep};
  constraints: Constraints;
  trace?: TripTrace;
  buses: Record<string, BusPosition>;
  user?: GpsFix;
  voice: {status: "off" | "connecting" | "listening" | "speaking"; transcript: Turn[]};
  renderer: "google3d" | "simworld";
  demo: {simulateWalk: boolean; replay: boolean};
};
```

All server events (`09-api-spec.md`) reduce into this store; components never call the planner directly.


---

# 09 — API Spec

Base URL `/api/v1`. JSON. Times ISO 8601 with offset. Errors: `{"error": {"code": "...", "message": "...", "details": {}}}`.

## 1. REST

### Places
`GET /places/search?q=klaus&near=33.777,-84.396&limit=8`
```jsonc
{"results": [{"kind": "building", "id": "klaus", "name": "Klaus Advanced Computing Building",
              "lat": 33.7772, "lng": -84.3963, "confidence": 0.97}]}
```

`POST /places/resolve` — `{"query": "the CRC", "near": {...}}` → `ResolveResult` (candidates + `needs_clarification`).

`GET /places/snap?lat=..&lng=..` → nearest walk node / building / entrance.

### Trips
`POST /trips/plan`
```jsonc
// request
{"constraints": Constraints, "now": "optional override for replay/tests"}
// response
{"trace": TripTrace}
```

`GET /trips/{trace_id}` → `TripTrace`

`POST /trips/{trace_id}/explain` — `{"question": "why not walk?"}` →
```jsonc
{"text": "...", "verified": true, "fallback_used": false, "facts_used": ["..."]}
```

### Buses
`GET /buses/live` → `{"as_of": "...", "feed_mode": "live|replay|schedule_only", "buses": [BusPosition]}`
```jsonc
// BusPosition
{"vehicle_id": "bus_14", "route_id": "route_x", "lat": 0, "lng": 0, "heading_deg": 0,
 "dist_along_m": 1234, "prev_stop_id": "...", "next_stop_id": "...", "updated_at": "..."}
```

`GET /routes` → routes with stops and encoded shapes.
`GET /stops/{stop_id}/arrivals?k=3` → next arrivals with p10/p50/p90 per route.

### Sessions
`POST /sessions` → `{"session_id": "s_..."}` (optionally initial constraints)
`POST /sessions/{id}/constraints` — body `ConstraintPatch` → `{"state": SessionState, "trace": TripTrace | null, "clarification": {...} | null}`
`POST /sessions/{id}/start` · `POST /sessions/{id}/end`
`GET /sessions/{id}` → `SessionState`

### Disruptions
`GET /disruptions?status=approved`
`POST /disruptions/ingest` (admin; triggers a Grok scan)
`POST /disruptions/{id}/approve` · `POST /disruptions/{id}/reject`

### Admin / demo
`POST /admin/replay` — `{"file": "weekday_sample", "speed": 5, "start_at_local": "08:00"}`
`POST /admin/simulate-walk` — `{"session_id": "...", "enabled": true, "speed_mps": 1.3}`
`GET /admin/metrics` — latency, verify pass rate, token/voice usage.

### Health
`GET /health` → `{"db": "ok", "redis": "ok", "feed": {"mode": "replay", "age_s": 3}, "xai": "ok"}`

## 2. WebSocket: `/ws/session/{session_id}`

Client → server:
```jsonc
{"type": "gps", "lat": 0, "lng": 0, "accuracy_m": 8, "heading_deg": 120, "ts": "..."}
{"type": "constraint_patch", "patch": ConstraintPatch}
{"type": "start"} | {"type": "end"}
```

Server → client:
```jsonc
{"type": "plan_updated", "trace": TripTrace, "reason": "constraint_change", "changed": ["arrive_by"]}
{"type": "situation_changed", "trace": TripTrace, "reason": "bus_late", "delta": {"leave_by_s": 120, "p_on_time": -0.02}}
{"type": "nav_step", "phase": "NAVIGATING", "nav_step": "AT_STOP", "instruction": {...}}
{"type": "instruction", "text": "Turn left toward Clough Commons", "distance_m": 40, "maneuver": {...}}
{"type": "bus_update", "buses": [BusPosition]}            // only buses relevant to the session
{"type": "disruption", "disruption": Disruption}
{"type": "arrived", "arrived_at": "...", "on_time": true}
{"type": "error", "error": {...}}
```

## 3. WebSocket: `/ws/voice/{session_id}`

Relay between the browser and the Grok Voice Agent realtime API.

Client → server: binary audio frames (format per xAI docs) and control messages:
```jsonc
{"type": "ptt_start"} | {"type": "ptt_end"} | {"type": "mode", "value": "ptt|vad"} | {"type": "language", "value": "es"}
```

Server → client: binary audio frames for playback, plus:
```jsonc
{"type": "transcript", "role": "user|assistant", "text": "...", "final": true}
{"type": "voice_status", "value": "listening|thinking|speaking"}
{"type": "verify", "turn_id": "...", "verified": false, "correction_queued": true}
```

The server handles tool calls itself (never forwarded to the client), applies results to the session, and emits the matching events on `/ws/session/{id}` so the map updates in sync with speech.

## 4. Shared schema source

Pydantic models in `services/api/app/models.py` are the source of truth. Generate TypeScript types with `openapi-typescript` from FastAPI's OpenAPI JSON; WebSocket message types live in a `ws_messages.py` module exported via a small JSON Schema build step.


---

# 10 — Evaluation, Explainability PDF, Demo

## 1. Evaluation sets (start building in Milestone 1, not at the end)

| Set | Size | Contents | Used for |
|---|---|---|---|
| `eval/od_cases.json` | 30 OD pairs × 3 times = 90 | Origin, destination, time, replay day, expert-labeled best choice (walk vs. which stop/bus) by a daily Stinger rider | Plan correctness |
| `eval/intent_cases.json` | 100 | Text and voice-transcript requests incl. nicknames, typos, relative times, stacked follow-ups → expected `ConstraintPatch` list | Intent accuracy |
| `eval/explain_cases.json` | 100 traces | Auto-generated from od_cases + perturbations | Verification pass rate, readability spot-check |
| `eval/voice_scripts/` | 10 scripted multi-turn sessions | Audio recordings or TTS of scripted users | End-to-end voice latency and correctness |
| Predictor holdout | Most recent N weeks | Time-based split | MAE, coverage, calibration |

## 2. Metrics dashboard (`scripts/eval_all.py` → `eval/report.md` + figures)

- Predictor: MAE by route × hour, interval coverage, pinball loss, vs. L0/L1 baselines.
- Planner: agreement with expert labels; minutes saved vs. walk-only and vs. schedule-only planner on replayed days (simulate a user following each plan, compute actual arrival from the recording).
- `p_on_time` calibration: reliability diagram (predicted bucket vs. actual on-time rate).
- Grok: intent exact-match and field-level accuracy; verification pass rate; fallback rate; median voice latency.
- Robustness: results with feed degraded to schedule-only.

## 3. Explainability PDF (6–8 pages)

Audience: judges and anyone asking "why should I trust it?"

1. **Summary** — what it does, who it helps, headline numbers.
2. **System overview** — architecture diagram; "the engine decides, Grok explains" rule.
3. **How a plan is chosen** — candidate generation, Monte Carlo evaluation, ranking, arrive-by search. One worked example with the full `TripTrace`.
4. **Arrival prediction** — model ladder, features, metrics vs. baselines, calibration plot, SHAP summary with a plain-English read.
5. **Where Grok is used, and where it isn't** — touchpoint table with tools and limits.
6. **Grounding and verification** — how numbers are checked; pass rate; two real examples of caught errors and the fallback shown.
7. **Voice session design** — constraint stacking, announcement policy, latency numbers.
8. **Disruptions** — from X/web post to approved graph edit, with the human approval step.
9. **Social impact and accessibility** — step-free routing, voice guidance, multilingual, night mode; who benefits.
10. **Limitations** — indoor gaps, feed reliability, model drift, GPS accuracy between buildings, privacy approach.
11. **Appendix** — tool schemas, prompts, data sources, AI dev log highlights.

Build from Markdown (`docs/explainability.md`) with figures generated by `eval_all.py`; export to PDF with pandoc or a docs tool so it stays in sync.

## 4. Demo (3 minutes)

| Time | Beat | On screen | Proves |
|---|---|---|---|
| 0:00–0:20 | Hook: a general map routes you through a locked building and doesn't know when the bus actually comes | Side-by-side: a generic route vs. ours | The problem is real |
| 0:20–1:05 | Voice: "Get me to Klaus by 8:30." | Map flies in, route draws, live bus approaches; Grok speaks leave-by and on-time chance | Voice + tools + deterministic engine + 3D |
| 1:05–1:30 | Stack: "Avoid stairs, I'm on crutches." | Route swaps to step-free; Grok confirms only the change | Constraint stacking, accessibility |
| 1:30–1:55 | Situation change (replay at 5x): bus slows | Banner + Grok: "Bus is 4 min late; walking now still gets you there by 8:28." | Live re-planning, proactive voice |
| 1:55–2:20 | "Why?" | Explanation with ✓ verified; expand numbers + ETA histogram | Explainability, grounding |
| 2:20–2:45 | Sim world toggle on an edge case (covered walkway / pass-through) | Our 3D world showing a path Google doesn't model | Why bounded scope wins |
| 2:45–3:00 | Under the hood | One slide: metrics vs. baselines, verification pass rate, disruption feed, Grok Bot report | Rigor + Grok depth |

### Demo safety checklist
- [ ] Replay mode on with the rehearsed recording; "simulate walk" on
- [ ] Voice tested on venue Wi-Fi and a phone hotspot; push-to-talk default
- [ ] Pre-recorded video of the full demo as backup
- [ ] Template explanations working with the xAI key removed
- [ ] 3D assets cached; renderer fallback tested
- [ ] xAI credits topped up; rate limits checked


---

# 11 — Build Plan

Each milestone ends with a demoable state and explicit acceptance checks. Do not start a milestone until the previous one passes. Time estimates assume a team of 3–4; adjust to your schedule.

## M0 — Data inventory and setup (≈ 0.5 day)
- [ ] Repo skeleton per `02` §4; Docker Compose with Postgres/PostGIS + Redis; `.env.example`
- [ ] `scripts/inventory.py` → `docs/DATA_INVENTORY.md` (`03` §1)
- [ ] Human review of inventory; `docs/OPEN_QUESTIONS.md` started
**Accept:** every file in the zip appears in the inventory with a proposed mapping or "unused" note.

## M1 — Normalize, georeference, walk routing in 3D (≈ 1.5 days)
- [ ] `normalize.py` produces all `03` §2 tables; `--check` passes or exceptions are documented
- [ ] `georef.py`: control points, transform, RMSE ≤ 2 m; Python + TS transforms unit-tested
- [ ] `build_graphs.py`: walk graph with all stops/entrances connected
- [ ] Planner walk-only + `TripTrace` skeleton
- [ ] Web: Google 3D renderer, tap-to-pick origin/destination, walk route drawn
- [ ] Start `eval/od_cases.json` (labels can come later)
**Accept:** any two tapped points produce a walk route on the 3D map in < 1 s; avoid-stairs toggle changes routes where stairs exist.

## M2 — Transit routing with history (≈ 1 day)
- [ ] Transit graph; ride candidates; L0 and L1 predictors
- [ ] Monte Carlo evaluation; ranking; alternatives and fallback in trace
- [ ] Plan card UI with walk-only comparison
- [ ] Golden-trace tests (seeded)
**Accept:** for 10 hand-picked cases, the plan choice matches a daily rider's judgment; golden tests stable.

## M3 — Live/replay buses + L2 predictor (≈ 1 day)
- [ ] Ingest: replay player (required), live poller (if feed access confirmed)
- [ ] L2 live-conditioned predictor; `p_catch`
- [ ] Bus markers gliding along shapes; `/ws/session` bus updates
- [ ] Record replay days
**Accept:** in replay at 5x, predicted arrivals converge as buses approach; `GET /health` shows feed mode/age.

## M4 — Arrive-by, sessions, live navigation (≈ 1.5 days)
- [ ] Arrive-by search (`04` §6); `leave_by`, `p_on_time`, `status`
- [ ] Session state machine, constraint patches, re-plan triggers with debounce
- [ ] Live view: follow camera, nav steps, at-stop countdown, on-bus mode, arrival
- [ ] Simulate-walk demo mode
**Accept:** a scripted replay session completes start → arrival with correct phase transitions; a forced bus delay triggers exactly one `situation_changed`.

## M5 — Grok text layer + knowledge base (≈ 1 day)
- [ ] Collections built from buildings/stops/policies; `resolve_place` fast path + Collections fallback
- [ ] Text agent with tools; search-bar structured intent parsing
- [ ] Explainer + verification layer + template fallback
- [ ] `intent_cases.json` and `explain_cases.json` evaluated
**Accept:** intent accuracy ≥ 95%; verification pass rate ≥ 98%; the app is fully usable with `XAI_API_KEY` unset (templates + tap).

## M6 — Voice session (≈ 1.5 days)
- [ ] Server relay to the Grok Voice Agent API; tool handling in the server
- [ ] Constraint stacking via `update_constraints`; clarification flow
- [ ] Proactive announcements with policy (`06` §5); hold while user speaks
- [ ] Transcript UI, push-to-talk + VAD toggle, multilingual check (one non-English language)
- [ ] Spoken-transcript verification + correction turn
**Accept:** the 10 scripted voice sessions pass; median time to first spoken word ≤ 1.5 s on good Wi-Fi.

## M7 — Stretch (pick by remaining time; in order)
- [ ] L3 ML predictor from the existing delay work (must beat L2 on holdout)
- [ ] Disruption ingest with approval UI
- [ ] Sim-world renderer + toggle
- [ ] Night mode; photo localization; waypoints; transfers
- [ ] Grok Bot ops bots (if access) or scheduled-script equivalents

## M8 — Eval, PDF, demo (≈ 1 day; never skip)
- [ ] `eval_all.py` report and figures
- [ ] `docs/explainability.md` → PDF
- [ ] `docs/AI_DEV_LOG.md` cleaned up
- [ ] Demo rehearsed 3× with the safety checklist; backup video recorded

## Cut lines (if time runs short)
1. Keep: M0–M4, M5 explainer + verification, M6 basic voice (request + one stacked constraint + one proactive update), M8.
2. Cut first: transfers, photo localization, Grok Bot, sim-world renderer (use screenshots of it in the PDF instead), L3 model (report L2).
3. Never cut: replay mode, verification, the eval numbers.


---

