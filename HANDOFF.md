# HANDOFF.md — StingerDelay-3D

**Purpose:** Give Cursor (or any coding agent) full context to continue work without re-discovering the project.

**Last updated:** 2026-11-02  
**Repo:** https://github.com/danmano411/StingerDelay-3D  
**Primary docs:**  
- `README.md` — hierarchy & ownership  
- `docs/PRODUCT_VISION.md` — product vision and executable breakdown  
- `docs/PLAN_UPDATES.md` — incremental notes  
- Full Buzz Route spec was provided in the original conversation (treat as ground truth; large file not fully committed yet)

---

## 1. What this project is

Voice-first, 3D multimodal navigation for Georgia Tech that combines:
- Campus walk graph
- Stinger bus routes + live/replay positions
- Delay prediction models from the existing **Stinger Delay** project
- Grok (Voice Agent + tools) as the interface

**Core rule (non-negotiable):**  
The routing engine owns every numeric value (times, distances, probabilities). Grok only interprets, speaks, and explains. Every number shown or spoken must come from a `TripTrace` and pass verification.

---

## 2. Product vision (summary)

**Grok Bot is the helper for Stinger Delay**, using three integrations:
1. Grok Voice Agent API
2. Google Calendar (next event / classes)
3. X (secondary social signals only)

**Target user flows:**
- “Hey Grok, using my calendar, when should I leave for the next event?”
- “If I leave now, will I be fine?”
- “Plan a path to Klaus by 8:30, avoid stairs.”
- “Look at my calendar, grab my classes, and create a bus schedule for the day.”
- Flick through a personal daily bus schedule that dynamically assigns buses based on current location, classes, and time.
- Local path storage (simple JSON / IndexedDB for now).

**Secondary X / social layer (not primary):**
- Game days, high post volume, or location-tagged posts → extra uncertainty or crowd heatmap.
- Inspired by https://waitz.io/gatech crowd levels.
- Applied as a secondary multiplier or wider quantile on top of the Stinger Delay predictor.
- Always badged; never overrides the deterministic engine.

**UI style:** PRT-style segmented plan card  
Walk to stop → wait → ride → (optional transfer) → final walk  
+ total ETA + `p_on_time` + confidence bands that widen with time horizon.

---

## 3. Repo hierarchy & ownership (do not violate)

| Path | Owner | Notes |
|---|---|---|
| `README.md` | Shared | Overview + hierarchy. Update carefully. |
| `docs/` | Shared | Vision, plan, inventory, open questions. |
| `apps/web/` | Web agent / Cursor | React + TS web app (current focus). |
| `apps/ios/` | iOS agent only | Native iOS. **Do not touch unless you are the iOS agent.** |
| `services/api/` | Shared backend | FastAPI planner, predictor, Grok tools, verification. |
| `data/` | Shared | Normalized data, graphs, models, replays. |
| `scripts/` | Shared | Inventory, normalize, build graphs, train, eval. |

**Rules:**
- Routing engine owns numbers.
- Prefer replay mode + simulate-walk for demos.
- Calendar = Google Calendar (next event / classes) for now.
- X / social signals are secondary only.

---

## 4. What already exists

- **Stinger Delay source**: Models, GPS/ETA datasets, analysis (in the original zip; also at https://github.com/gt-big-data/stinger-delay). Documented ~44–54% better than TransLoc.
- **Route geometry**: Polylines for Stinger routes.
- **Full Buzz Route spec**: Architecture, data contracts, routing engine (Monte Carlo quantiles), voice session, Grok integration, verification layer, frontend 3D abstraction, API, eval, and build plan. Ground truth for the rebuild.

---

## 5. What needs to be built (priority order)

1. Deterministic planner: walk graph + transit graph + Monte Carlo evaluation using Stinger Delay quantiles → `TripTrace`.
2. PRT-style segmented plan card + confidence bands that widen with horizon.
3. Calendar tool + local path storage schema.
4. Voice Agent relay + in-app Grok helper.
5. Secondary X signal ingest (crowds / events → extra uncertainty).
6. Sessions, re-planning, verification layer, explainability.
7. iOS agent consumes the same backend APIs (concurrent, separate ownership).

---

## 6. Immediate next actions for Cursor

1. Clone the repo and open it in Cursor.
2. Read `README.md` and `docs/PRODUCT_VISION.md`.
3. Start the web app skeleton under `apps/web/` (React + TS + Vite recommended per spec).
4. Implement the shared planner contract first so both web and iOS can consume it.
5. Keep all numeric outputs inside `TripTrace`. Add verification before any Grok speech or display.

---

## 7. Key technical contracts (short)

- **Constraints**: origin, destination, arrive_by / depart_at, prefs (avoid_stairs, walk_speed, etc.).
- **TripTrace**: chosen plan + alternatives + quantiles (p10/p50/p90) + p_on_time + p_catch + legs (walk/wait/ride) + explanation_facts.
- **Arrive-by**: binary search for latest leave-by that meets on-time target.
- **Confidence**: tighter near-term (live bus visible), wider far-term.
- **Verification**: extract numbers from Grok output and check against allowed set from the trace; fallback to template on failure.

---

## 8. Related links

- Stinger Delay: https://github.com/gt-big-data/stinger-delay
- Crowd reference: https://waitz.io/gatech
- Cursor CLI: https://cursor.com/docs/cli

---

## 9. Open questions / notes

- Full `BUZZ_ROUTE_SPEC.md` content is large; key sections are summarized above. Prefer the original spec language when implementing.
- Delay models rest on limited days of data — label uncertainty.
- Secrets (xAI key, Maps key) stay server-side.

**End of handoff.**  
Start from the hierarchy, keep the engine deterministic, and make the Grok Bot helper (Voice + Calendar + secondary X) the user-facing layer.

## 10. Base data now in repo

Non-solar baseplate from the previous project:

- `data/base/routes.json` — Stinger route polylines and colors
- `data/base/campus.json` — campus building / geometry data
- `reference/stinger-delay-summary.md` — model comparison results (44–54% better than TransLoc)

The full Stinger Delay source (GPS logs, notebooks, trained model artifacts) lives in the original zip and at https://github.com/gt-big-data/stinger-delay. Use these files as the starting point for the planner and predictor. No solar content was imported.
