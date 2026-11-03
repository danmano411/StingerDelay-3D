# Plan 2: Web app and 3D sim planner

**Goal:** a web app where someone plans a trip and watches it play out on the 3D campus. The iOS app can reuse the same 3D view.

**Spec:** `docs/spec/BUZZ_ROUTE_SPEC.md` section 08. **Existing task detail:** A5, B4 to B6 and C2 in `docs/superpowers/plans/2026-11-02-parallel-e2e-web.md`.

## The 3D sim planner
It answers "what happens if I leave at this time?" by playing the plan on the real campus.

| Part | Behavior |
|---|---|
| Pick | Click a building or stop to set From or To, or use search or voice |
| Route | Walk legs dashed, ride legs solid in the route color, so color isn't the only cue |
| Clock | Play, pause and scrub at 1x to 20x, starting from the plan's leave-by time |
| Simulate | A walker follows each walk leg, waits at the stop, then follows the replay bus |
| What-if | Changing the leave time requests a new `TripTrace`. The scene never computes its own numbers |
| Outcome | Shows on time or late, using `p_on_time` from the trace. Far-off trips show wider bands and "check again closer to departure" |

Motion may interpolate along a leg for display only. Every number on screen comes from the trace, and the UI labels the scene "replay" so nobody takes it for live buses.

## W1. Clean baseplate and bridge (2:00-10:00)
**Paths:** `web-sim/`, `docs/contracts/sim_bridge_v0.md`

- [ ] Remove the solar, materials and energy panes and KPIs. Keep the sun for lighting only. Rebrand the page.
- [ ] Move `web-sim/data.js` loading behind a loading state so it doesn't block the app's first paint.
- [ ] Add a query flag `?embed=1` that hides all page chrome.
- [ ] Define and implement the bridge. **This is the iOS contract, so publish it first.** Messages use `postMessage` on web and `evaluateJavaScript` plus `webkit.messageHandlers.simBridge` on iOS:
  - In: `plan.show {trace}`, `plan.clear`, `clock.set {iso, speed, playing}`, `camera.focus {place_id}`
  - Out: `sim.ready`, `sim.pick {place_id, lat, lng}`, `sim.clock {iso}`
- [ ] Convert coordinates with the scene's own origin (`meta.origin`), the same projection as the data.

**Done when:** `?embed=1` shows only the campus, a fixture trace draws its route, and clicking a building emits `sim.pick`.

## W2. App shell and plan card (2:00-10:00)
**Paths:** `apps/web/src/pages/`, `apps/web/src/components/` (except `CampusMap.tsx`), `apps/web/src/api/`, `apps/web/src/storage/`

- [ ] Replace the scaffold with one main screen: the 3D view with a bottom sheet on phones and a side panel on desktop.
- [ ] Generate API types from `services/api/openapi/openapi.yaml`. Don't hand-copy them.
- [ ] Plan card with segments for walk, wait, ride and walk: per-leg duration, total ETA, `p_on_time`, leave-by and a confidence band.
- [ ] Today page for `DayPlan`: flick through trips, with each showing leave-by and "walk" or "take the Red". Load from fixtures until E3 lands.
- [ ] Save plans to IndexedDB using `docs/contracts/local_plan_v0.json`.
- [ ] Empty, loading and error states. Show mock and replay labels. Text labels on every map state, keyboard use, 44 px targets, and `prefers-reduced-motion`.
- [ ] Deliberate look: GT navy and gold, flat, small corner radii, no purple gradients, no generic template feel.

**Done when:** a fixture trace renders correctly at phone and desktop widths and `npm run build` passes with the main bundle excluding `data.js`.

## W3. Sim planner in the app (10:00-15:00)
**Paths:** `apps/web/src/components/CampusMap.tsx`, `apps/web/src/sim/`, `web-sim/` (planner behavior)

- [ ] Embed `web-sim/?embed=1` in the app and connect the bridge.
- [ ] Connect picks to From and To, plan results to `plan.show`, and the clock to `clock.set`.
- [ ] Add the walker and bus-follow playback, the scrubber and the leave-time what-if.
- [ ] Add a visible 2D or list fallback for when WebGL is unavailable.

**Done when:** on the real API, clicking two buildings draws a plan, pressing play moves the walker onto the bus and to the destination, and changing the leave time updates the card and the route.

## For the iOS agent
Pull `main` and watch `docs/contracts/sim_bridge_v0.md`, `services/api/openapi/openapi.yaml` and `docs/IOS_AGENT.md`. iOS bundles its own copy of the twin, so it should re-copy `web-sim/` into `apps/ios/BuzzRoute/BuzzRoute/Resources/Twin/` when W1 and W3 land, then replace `RoutingEngine.swift` numbers with API calls. The web agents don't touch `apps/ios/`.
