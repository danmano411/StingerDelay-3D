# StingerDelay-3D: 20-minute parallel build

Three plans get the web app working end to end. They follow `HANDOFF.md`, `docs/PRODUCT_VISION.md` and `docs/spec/BUZZ_ROUTE_SPEC.md`, where the spec's full milestones remain the long-term target. These plans are the time-boxed path to a working demo.

| Plan | Owns | Delivers |
|---|---|---|
| [1. Engine and data](01-engine-and-data.md) | `services/api/` core, `scripts/`, `data/` | `POST /trips/plan`, day plans, replay buses, number verification |
| [2. Web app and 3D sim planner](02-web-and-3d-sim-planner.md) | `apps/web/`, `web-sim/` | Plan card, schedule, 3D planner, iOS bridge |
| [3. Grok integrations](03-grok-integrations.md) | `services/api/grok/`, `apps/web/src/grok/` | Voice assistant, calendar day planner, live X feed |

## Timeline: hard stop at 20:00

| Clock | Who | Work | Must be true at the end |
|---|---|---|---|
| 0:00-2:00 | Lead | Task 0 below | Wave A is on `main`; contracts are frozen |
| 2:00-10:00 | 6 agents at once | E1, E2, W1, W2, G1, G2 | Each agent's own tests pass; each has pushed |
| 10:00-15:00 | 3 agents at once | W3, G3, E3 | The demo path runs |
| 15:00-18:00 | Lead | Integrate and run the gates | All gates below pass, or the failure is recorded |
| 18:00-20:00 | Lead | Runbook, final push, report | `main` is what was tested |

At each deadline, ship what passes and cut the rest using the cut list. Nobody starts new work after 15:00.

## Task 0: lead, before anything else
1. `git pull --ff-only`.
2. Run `pytest services/api/tests` and `npm run build` in `apps/web`. Then commit and push the uncommitted Wave A work (`apps/web/`, `services/`, `scripts/`, `data/normalized/`, `docs/contracts/`, `docs/IOS_AGENT.md` and the notes).
3. Add these fields to the contracts, additive only: `TripTrace.status`, `DayPlan`, `XFeedItem`, `FeedStatus`. Publish the updated `services/api/openapi/openapi.yaml`.
4. Confirm `git check-ignore .env`. Check any Grok key with `GET https://api.x.ai/v1/models`.

## Parallel rules
1. **Disjoint paths.** Each task lists its paths. Touch nothing else. To change another task's path, message the lead.
2. **Never edit `apps/ios/`.** That belongs to the iOS agent.
3. **Push after every task.** Use small commits to `main`, running `git pull --rebase` first. The iOS agent pulls continuously.
4. **Contracts are additive after 2:00.** Renaming or removing a field needs the lead, and a note in `docs/notes/EXECUTION_LEDGER.txt`.
5. **Build against fixtures.** Use `services/api/tests/fixtures/` and mock responses until the real dependency lands. Nobody waits for another agent.
6. **The engine owns every number.** Grok interprets, speaks and explains. Numbers come from `TripTrace` and pass verification.
7. **Secrets stay in the environment.** The repo's `.env` is git-ignored. No key goes in a file that gets committed, a log or the client bundle.
8. **No coding-assistant signature, anywhere.** No co-author trailers, "generated with" lines, or tool names in commits, PRs, docs or code.
9. **Blue stays flagged synthetic.** No solar, PV, materials or energy UI ships. Real data and mock data are labeled as such.
10. **Fast model for scaffolding and UI; strongest model for the planner, verification and integration.**

## Key gates: the build stops and asks the user at these points
| Gate | Needed | Unlocks | Without it |
|---|---|---|---|
| **K1** | Working xAI API key with credits, from console.x.ai | Voice-to-text, Grok chat, live X feed | Template replies and labeled sample feed |
| **K2** | Google OAuth client ID and secret | Live Google Calendar sign-in | `.ics` import and sample schedule |
| K3 (optional) | `GT_BUS_API_KEY` | Live bus positions | March 2026 replay |

No X API key is needed. X search runs through the xAI key. Google Maps isn't needed either, because the 3D view is our own Three.js campus.

## Gates before the final push
```bash
pytest services/api/tests
(cd apps/web && npm run build)
python scripts/e2e_smoke.py                 # plan, arrive-by, day plan, feed, verification
git grep -il 'cl[a]ude\|anthr[o]pic' ; git log --all --format=%B | grep -i 'cl[a]ude\|anthr[o]pic'    # both must print nothing
git grep -nE 'xai-[A-Za-z0-9]{20,}|grok_[a-f0-9]{20,}'                                                # must print nothing
```
Then run the demo path by hand with the key removed, and again with it set.

## Demo path (definition of done)
1. Open the app and see the 3D campus with replay buses and no solar UI.
2. Say "get me to Klaus by 8:30, avoid stairs." The transcript appears, the plan card fills in, and the route draws in 3D.
3. Press play. The clock runs, the walker and the bus move, and the on-time result shows.
4. Open Today. Each calendar event has a leave-by time and a recommendation to walk or take a specific bus.
5. See the live X feed. A relevant post widens the confidence band and adds a badge, and it never moves the median.
6. Ask "why this bus?" and get a verified answer, or the labeled template.

## Cut list, cut in this order
1. Realtime speech-to-speech. Keep push-to-talk transcription.
2. Spoken replies. Keep text.
3. Google OAuth. Keep `.ics` import and the sample schedule.
4. X feed effect on plans. Keep the feed display, labeled.
5. Transfers, stairs data and buses other than the next few.

**Never cut:** replay mode, number verification, the template fallback, or the 3D route draw.

## What these plans knowingly defer from the spec
Postgres and Redis (JSON files and memory for now), the OSM walk graph (straight-line distance with a street factor, labeled as an estimate), trained model serving (ETA lookup first), sessions over WebSocket, and the eval suite with the explainability PDF. Stairs routing can't be real without the walk graph, so `avoid_stairs` only applies a slower speed and shows "stairs data not available yet."
