# iOS agent handshake

**Owner of this doc:** web / shared agent  
**Owner of `apps/ios/`:** iOS agent only — web agent will not touch it.

## What you can consume now / soon

| Artifact | Path | Status |
|---|---|---|
| OpenAPI | `services/api/openapi/openapi.yaml` | Wave A1 |
| TripTrace models | `services/api/contracts/` | Wave A1 |
| Local plan schema | `docs/contracts/local_plan_v0.json` | Wave B6 |
| Normalized stops/routes | `data/normalized/` | Wave A4 |
| Planner | `POST /trips/plan` | Wave B2 |
| Calendar (mock/live) | `GET /calendar/next` | Wave C1 |
| Social factor (secondary) | `GET /signals/x` | Wave C4 |

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

## Contract version

`v0` — breaking changes will bump to `v1` and be noted in `docs/notes/EXECUTION_LEDGER.txt`.
