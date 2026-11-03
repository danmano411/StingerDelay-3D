# sim_bridge v0

Transport: web `window.postMessage(msg, "*")`; iOS `window.simBridge.receive(msg)` via evaluateJavaScript. Messages are `{type, ...}`.
Out (page to parent): web `window.parent.postMessage`; iOS `window.webkit.messageHandlers.simBridge.postMessage(msg)`.

## In
- `plan.show {trace}`: `trace.plan.legs[]` each `{kind: walk|wait|ride|transfer_walk, path: [[lat,lon],...], route_id, duration_s_p50, label}`. Draws route, frames camera.
- `plan.clear`
- `walk.start {speed?}`: optional multiplier on the shared clock. By default the walker and buses both run at 5x real time, so a trip takes its planned duration divided by 5. Change the rate with `?speed=N` on the page URL.
- `walk.stop`
- `camera.focus {lat,lon}`

## Out
- `sim.ready`
- `sim.pick {name,lat,lon}`: building click
- `walk.progress {leg_index, leg_kind, fraction, lat, lon}`: 4 Hz
- `walk.done`

Params: `?embed=1` hides chrome; `?demo=1` self-feeds a fixture trace and auto-starts.
No numeric ETA is rendered in the scene.
