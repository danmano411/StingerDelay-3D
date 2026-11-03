# Grok chat contract v0

`POST /grok/chat`
Request: `{conversation_id: str, message: str, now?: iso8601, origin?: {lat, lon}}`
Response:
```
{conversation_id, reply: str, source: "grok"|"local", verified: bool,
 action: "show_path"|"walk"|"stop_walk"|null,
 trace: TripTrace|null,
 clarification: {question, options:[str]}|null,
 events?: [{title, location, start, end, source, mode: "walk"|"bus"|null, leave_at, trace}]}
```
- Constraints accumulate per conversation_id; follow-ups ("make it 8:15", "avoid stairs", "from the CRC") re-plan.
- No destination: `action` null, reply asks where and by when.
- Plan: `action` "show_path" with `trace`. "walk it": `action` "walk" with the current trace, or an error reply with null trace when nothing is planned. "stop": `action` "stop_walk".
- Origin defaults to Student Center; the reply says "from Student Center".
- `verified` true only when the reply passed numbers verification. On failure the reply is the template text and `verified` is false.
- Times are America/New_York.

`GET /grok/status` -> `{provider: "grok"|"local", key_present, key_valid, detail}` (never the key).
`POST /grok/transcribe` multipart `file` -> `{text}`; 503 `{detail: "use browser speech"}` when no valid key.
`GET /calendar/status|next|day`, `POST /calendar/import` (raw .ics text or `{url}`), `GET /signals/x/feed` -> `{status, items, detail}`.

## Position
- With `origin {lat, lon}` the plan starts "from your location". Without it the start is Student Center and the reply says "(default start)". A spoken "from X" overrides GPS.
- An origin more than 3 km from Student Center is rejected: `action` null, reply says you're off campus, `clarification` = `{question: "Where should I start from?", options: [...]}`.

## Stated current time
"...by 8:30, and right now it's 6" plans with now = 6:00 today (am or pm, whichever lands before the deadline, the later one). The stated now persists for the conversation's follow-ups. Replies state leave-by, bus (if any), on-time chance and the p10-p90 arrival range; `trace.plan.p_on_time` and `trace.plan.total_s {p10,p50,p90}` carry the numbers.

## Weekly routes
`GET /routes/week?user=demo&refresh=false` -> `{source: "sample"|"ics", user, week_of, days: {monday: [entry], ..., friday: [entry]}}`; entries are the same as `POST /day/plan` (`{event, trace, needs_place, recommendation, leave_by}`). The sample schedule differs per weekday. `.ics` events with `RRULE:FREQ=WEEKLY;BYDAY=MO,WE` are expanded. Weeks are saved to `data/user/<user>_week.json` (git-ignored) and reused until the week changes or a calendar import happens.
Chat: "what's my Monday route" / "plan my week" -> `events` rows `{title, location, start, end, mode, leave_at, trace, weekday}`, `action` null.
