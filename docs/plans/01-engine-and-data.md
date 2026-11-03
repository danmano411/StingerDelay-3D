# Plan 1: Engine and data

**Goal:** one deterministic API that web and iOS both use. It is the only source of times, distances and probabilities.

**Spec:** `docs/spec/BUZZ_ROUTE_SPEC.md` sections 03, 04, 05 and 09. **Existing task detail:** B1 to B3 and C2 in `docs/superpowers/plans/2026-11-02-parallel-e2e-web.md`.

## E1. Predictor and replay (2:00-10:00)
**Paths:** `services/api/predictor/`, `services/api/replay/`, `scripts/build_delay_lookup.py`, `scripts/build_replay.py`, `data/normalized/delay_lookup.json`, `data/replays/`

- [ ] Build the lookup from the delay study's real data if reachable: `github.com/danmano411/stinger-delay`, branch `model-comparison`, `Analysis/model_comparison/` (`raw_data/`, `datasets/`, `results/`). Bucket by TransLoc ETA. If it can't be built in time, use the bands in `reference/stinger-delay-summary.md` and name the model `eta_decile_summary_v0`.
- [ ] `quantiles(route_id, eta_s, horizon_s, social_factor=None)` returns `p10`, `p50`, `p90`. Bands widen with horizon: tight under 3 minutes, wide at 60 to 90 minutes.
- [ ] `social_factor` only widens the spread. It never moves `p50`. Test this.
- [ ] Extract each route's replay from `web-sim/data.js` (`routes[i].replay`) into small per-route JSON files.
- [ ] `GET /buses/live` returns replay positions for a clock time, with `feed_mode: "replay"`. Blue carries `synthetic: true`.

**Done when:** tests prove the bands widen with horizon, the median is unchanged by a social factor, and replay payloads are under 1 MB per route.

## E2. Planner and verification (2:00-10:00)
**Paths:** `services/api/planner/`, `services/api/verify/`, `services/api/routers/trips.py`

- [ ] Walk: distance is straight-line times 1.3, at `walk_speed_mps` (default 1.3 m/s). Mark walk legs `estimate: true`.
- [ ] Candidates: walking only, plus walk, wait, ride, walk for stops within 700 m at both ends. Handle loop routes.
- [ ] Monte Carlo with 300 samples and a seed taken from a hash of the inputs, so identical requests return identical traces.
- [ ] Arrive-by: binary search at 30-second steps for the latest leave-by that meets `p_on_time >= 0.9`. Otherwise return the best plan with `status: "at_risk"`.
- [ ] `TripTrace` includes alternatives, `p_catch`, `explanation_facts` and `allowed_numbers`.
- [ ] `verify.check(text, trace)` finds times, durations, distances and percentages in text and allows only those in the trace, with the rounding tolerance in spec section 07 part 6. `verify.template(trace)` builds the fallback answer.

**Done when:** Student Center to Klaus and Klaus to Kendeda both return full traces under 1 second; walking is always an alternative; `p10 <= p50 <= p90`; verification rejects an invented time and accepts the trace's own.

## E3. Day planner and smoke test (10:00-15:00)
**Paths:** `services/api/planner/day_plan.py`, `services/api/routers/day.py`, `scripts/e2e_smoke.py`

- [ ] `POST /day/plan` takes an ordered list of events (`title`, `place`, `start`, `end`) and an optional start location, and returns a `DayPlan`.
- [ ] Each trip runs from the previous event's place to the next event's place, with `arrive_by` set to that event's start. The first trip starts at the given location.
- [ ] Each entry has its `TripTrace`, a leave-by time, and `recommendation: "walk" | "bus"` taken from the chosen plan. A place that can't be resolved returns `needs_place`. Don't guess.
- [ ] `scripts/e2e_smoke.py` runs through plan, arrive-by, day plan, feed, and a failed verification, using only the API.

**Done when:** three sample classes return three traces, one unresolvable place is flagged, and the smoke script exits 0 with no keys set.

## Facts for the demo
State them with their limits: the delay models cut arrival-time error by 44 to 54% (256-290 s to 127-143 s), on seven days of data. Clough has no delay model because its scraper never saved the stop ID. Blue has no GPS logs.
