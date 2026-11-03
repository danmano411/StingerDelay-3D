# Plan 4: Port the web experience to iOS

**Run this as a separate parallel agent, in `apps/ios/` only.** The web app is the design reference. Pull `main` before every task, and repeat this plan whenever the contracts or web app change.

## Sources of truth
| What | Where |
|---|---|
| API | `services/api/openapi/openapi.yaml` |
| Assistant | `docs/contracts/grok_chat_v0.md` |
| 3D scene | `docs/contracts/sim_bridge_v0.md`, `web-sim/` |
| Saved plans | `docs/contracts/local_plan_v0.json` |
| Screens and behavior | `apps/web/src/` |

## Primary path: same as web
1. Tap the mic and say "Get me to Klaus by 8:30."
2. See the plan card with leave-by time, on-time chance and likely arrival range.
3. See the route in the 3D campus.
4. Say "walk that path" or tap the button, and watch the person walk it.

## Tasks, parallel where paths don't overlap
| Task | Paths | Work | Done when |
|---|---|---|---|
| I1 API client | `Services/API/` | Replace `RoutingEngine.swift` numbers with `POST /grok/chat` and `POST /trips/plan`. Set the base URL in config | Every number on screen comes from a server `TripTrace` |
| I2 Voice | `Services/Voice/`, `Views/Grok/` | Tap to talk with `SFSpeechRecognizer`, then send the text to `/grok/chat`. Send `origin` from Core Location | "Get me to Klaus" plans from the user's real position |
| I3 3D bridge | `Resources/Twin/`, `Views/Twin/` | Re-copy `web-sim/` into the bundle. Connect `window.simBridge.receive` and the `simBridge` message handler | A chat plan draws in 3D and the person walks it |
| I4 Plan card | `Views/Plan/` | Match web segments and the likely arrival range, using native components | Matches the web card's content at phone width |
| I5 Week | `Views/Week/` | Mon-Fri control from `GET /routes/week`, with local copies matching `local_plan_v0` for offline viewing | Each weekday shows its trips, offline too |
| I6 Native polish | `Views/` | SwiftUI idioms, Dynamic Type, VoiceOver labels, 44 pt targets, reduced motion, haptic on step changes | Passes an accessibility inspector run |

## Rules
- Don't compute or invent numbers in the client. Unit conversion and rounding only.
- No API key in the app. All Grok calls go through the server.
- For a physical device, the API must be on a reachable network address, not `127.0.0.1`.
- Keep labels for replay buses, estimated walking times, sample calendars and Blue as synthetic.
- Report any contract gap to the web agent instead of editing outside `apps/ios/`.
