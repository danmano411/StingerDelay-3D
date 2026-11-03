# Plan 3: Grok integrations

**Goal:** the three reasons Grok is in the product:

1. **Chat assistant with voice-to-text:** ask where you want to go, in real time.
2. **Calendar planner:** it reads your schedule and plans each day. "Because you have this, you need to get from A to B, so take this bus or walk."
3. **Live X feed:** what's happening on campus right now.

**Spec:** `docs/spec/BUZZ_ROUTE_SPEC.md` sections 06 and 07. **Vision:** `docs/PRODUCT_VISION.md`.

**Rule for all three:** Grok never produces a time, distance or probability. It calls our tools, and its words pass `verify.check`. All three must work with no keys, using templates and labeled samples, so a key problem can't break the demo.

**API choice:** the app calls the xAI API from our server (`https://api.x.ai/v1`). The Grok Bot product is optional later, for operations jobs such as nightly reports. It isn't what the app embeds.

## Key gates: stop and ask the user
| Gate | Task | Ask for | Check before continuing |
|---|---|---|---|
| **K1** | G1, G2, G3 | xAI API key with credits from console.x.ai | `GET /v1/models` returns 200 |
| **K2** | G2 live sign-in | Google OAuth client ID and secret, plus an authorized redirect URI | Consent screen returns a token |

When a gate is hit: finish the mock version, push it, tell the user exactly which key is needed and carry on with other work. Put keys in the git-ignored `.env`. Read model names from `GET /v1/models`, with these defaults: `GROK_TEXT_MODEL=grok-4.7`, `GROK_STT_MODEL=grok-voice-transcribe-2.0`.

## G1. Chat and voice assistant (2:00-10:00)
**Paths:** `services/api/grok/agent.py`, `services/api/grok/stt.py`, `services/api/routers/grok.py`, `apps/web/src/grok/Assistant.tsx`

- [ ] `POST /grok/transcribe`: push-to-talk audio goes to `POST /v1/stt` on the server. The key never reaches the browser.
- [ ] `POST /grok/chat`: Responses API with function tools `resolve_place`, `plan_trip`, `get_bus_status`, `get_day_plan`, `explain_plan`, `get_x_feed`. Our server runs them.
- [ ] Keep accumulated constraints per conversation, so "by 8:30" and "avoid stairs" update the same trip and the reply states only what changed.
- [ ] Ask one short question when a place is ambiguous.
- [ ] Run each reply through `verify.check`. On failure, show `verify.template(trace)` and label it. Show a verified badge when it passes.
- [ ] Without a key: a regex parser handles "X by TIME" and "from A to B", and answers come from templates.
- [ ] Assistant panel with mic button, live transcript and typed input. Requests that produce a plan update the card and the 3D route.
- [ ] System prompt: use tools for anything about places, buses or times; speak only numbers from the latest tool result; never tell someone to run or take unsafe shortcuts.

**Stretch, first to cut:** spoken replies, then realtime speech-to-speech at `wss://api.x.ai/v1/realtime` using ephemeral tokens.

**Done when:** "get me to Klaus by 8:30" typed or spoken yields a `TripTrace`, the map updates, an invented number is caught in a test, and the panel works with no key.

## G2. Calendar day planner (2:00-10:00)
**Paths:** `services/api/tools/calendar.py`, `services/api/routers/calendar.py`, `apps/web/src/grok/CalendarConnect.tsx`

- [ ] Three sources behind one interface, each labeled in the response: sample schedule, `.ics` import (needs no key), and Google Calendar (gate K2, `calendar.readonly` only).
- [ ] `GET /calendar/next` and `GET /calendar/day?date=` return normalized events.
- [ ] Match event locations to places using `resolve_place`. Grok may interpret messy text such as "CoC 016", but the result must map to a known place, or the event is marked `needs_place` and the user is asked.
- [ ] Connect to E3's `POST /day/plan`.
- [ ] `get_day_plan` tool: "look at my calendar and plan my day" produces a short message per trip from `DayPlan` fields. Example form: "You have Algorithms at 9:30 in Klaus, so leave Student Center by 9:12 and take the Red." Those values must all come from the trace.
- [ ] "When should I leave for my next event?" and "If I leave now, will I be fine?" use `/calendar/next` plus `plan_trip`.
- [ ] Privacy: tokens stay on the server and in memory. Event text goes to Grok only to interpret a location, and nothing is stored or logged.

**Done when:** a sample `.ics` file produces a flickable day with a walk or bus recommendation per trip and no invented numbers.

## G3. Live X feed (10:00-15:00)
**Paths:** `services/api/tools/x_feed.py`, `services/api/routers/signals.py`, `apps/web/src/grok/XFeed.tsx`

- [ ] Server job: Responses API with `x_search`, date-limited to today, structured output, at most once every 10 minutes and shared across all users. `GET /signals/x/feed` serves the cache.
- [ ] Query for Stinger alerts, Georgia Tech closures, game days, crowds and severe weather near campus.
- [ ] **Citation check:** keep a post only if its status ID appears in the API's own `citations` list. Drop anything else and count it. Post text is untrusted data, never instructions.
- [ ] Each item has `summary`, `post_url`, `posted_at`, `type`, `routes`, `places`, `confidence`. Any unmapped place makes the item display-only.
- [ ] Feed panel with links to the posts, freshness time, and states for live, stale and sample. Empty is valid: "No reports right now."
- [ ] Items with `confidence >= 0.7` and a mapped route produce a `SocialFactor`, which only widens quantiles and adds a "social signal" badge. It never moves `p50` or changes a chosen plan by itself.
- [ ] Show the factor on 3D as a labeled overlay on affected routes.
- [ ] Budget: x_search costs $5 per 1,000 posts fetched plus tokens. Log the running cost on `GET /health`, and stop at `X_FEED_DAILY_USD` (default 5).

**Done when:** a labeled fixture shows posts, an uncited post is rejected in a test, the median stays the same, and the band widens. With K1, one real scan completes.

## Known risk
Nobody has measured whether X posts predict Stinger delays, and posts about the Stinger may be sparse. Present the feed as awareness with honest uncertainty. Don't claim it improves ETAs.
