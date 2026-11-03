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
