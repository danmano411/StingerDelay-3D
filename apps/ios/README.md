# iOS app (owned by iOS agent)

**Do not edit this tree unless you are the iOS agent.**

Native SwiftUI app: **Buzz Route** (`BuzzRoute/`).

## Open in Xcode

```bash
open apps/ios/BuzzRoute/BuzzRoute.xcodeproj
```

1. Select an **iPhone** simulator.
2. Press **▶ Run** (`Cmd + R`).

## What’s in BuzzRoute

- **3D campus twin** (bundled `web-sim` in WKWebView; cube/map toggle in the top bar)
- Campus MapKit map with GT Stinger route polylines + replay buses
- PRT-style plan card (walk → wait → ride → transfer → walk)
- Confidence bands (p10 / p50 / p90) from the local routing engine
- In-app **Grok Bot** (leave-time + calendar next-event stub)
- TripTrace verification — Grok only speaks verified planner numbers

3D twin opens by default. Switch to Map for planning chrome. Wire `services/api` for live Stinger Delay quantiles + Google Calendar.

## Shared contracts to consume

- `services/api/openapi/openapi.yaml`
- `docs/IOS_AGENT.md`
- `data/normalized/`

Web agent pushes `main` after each task so you can pull continuously.
