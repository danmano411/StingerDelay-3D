# StingerDelay-3D

Voice-first, 3D multimodal navigation for Georgia Tech (walk + Stinger buses + Grok).

**Repo:** https://github.com/danmano411/StingerDelay-3D  
**Handoff for agents:** [`HANDOFF.md`](HANDOFF.md)  
**Product vision:** [`docs/PRODUCT_VISION.md`](docs/PRODUCT_VISION.md)  

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
